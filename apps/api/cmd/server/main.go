package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/normalcoderJM/accountIng/apps/api/internal/auth"
	"github.com/normalcoderJM/accountIng/apps/api/internal/config"
	"github.com/normalcoderJM/accountIng/apps/api/internal/db"
	"github.com/normalcoderJM/accountIng/apps/api/internal/health"
	"github.com/normalcoderJM/accountIng/apps/api/internal/households"
	"github.com/normalcoderJM/accountIng/apps/api/internal/transactions"
)

func main() {
	// 1.加载环境变量配置 从config里拿
	cfg, err := config.Load()
	if err != nil {
		log.Fatal("load config", err)
	}
	// 2.连接数据库
	database, err := db.Open(cfg.DatabaseURL)
	if err != nil {
		log.Fatal("open database", err)
	}
	// main函数结束前关闭数据库连接池
	defer database.Close()
	// 3.创建业务依赖
	// --------登录注册业务-------
	authStore := auth.NewStore(database)
	authService := auth.NewService(authStore, cfg.JWTSecret, 3*time.Second)
	authHandle := auth.NewHandle(authService, cfg.JWTSecret)
	// --------登录注册业务-------
	//  ------家庭账本模块-------
	householdStore := households.NewStore(database)
	householdService := households.NewService(householdStore)
	householdHandle := households.NewHandle(householdService)
	// 账单数据层 只负责sql
	transactionStore := transactions.NewStore(database)
	transactionService := transactions.NewService(transactionStore, householdService, 3*time.Second)
	transactionHandle := transactions.NewHandle(transactionService)

	// 4.创建gin路由
	r := gin.Default()
	// 健康接口检查 不需要登录
	r.GET("/health", health.Handler)
	// 所有api使用前缀
	api := r.Group("/api/v1")
	// 注册、登录、当前用户等接口
	authHandle.RegisterRoutes(api)
	// 挂载protected路由组 所有的路由都需要鉴权
	protected := api.Group("")
	protected.Use(auth.AuthMiddleware(cfg.JWTSecret))
	// 注册账单接口
	householdHandle.RegisterRouter(protected)
	transactionHandle.RegisterRouter(protected)

	//  ------账单模块-------
	// 5.创建标准的http server
	server := &http.Server{
		// 监听地址，例如 :8080
		Addr: cfg.HTTPAddress,

		// Gin 实现了 http.Handler 接口
		Handler: r,

		// 最多等待 5 秒读取请求头
		ReadHeaderTimeout: 5 * time.Second,

		// 最多等待 10 秒读取完整请求
		ReadTimeout: 10 * time.Second,

		// 最多等待 15 秒写回响应
		WriteTimeout: 15 * time.Second,

		// 长连接空闲 60 秒后关闭
		IdleTimeout: 60 * time.Second,
	}

	// 6. 创建服务器错误通道
	//  ListenAndServe 返回的错误会通过这个 channel
	// 传回 main goroutine。
	// 缓冲区设置为 1，防止服务器 goroutine 在 main 还没有读取时被阻塞。
	serverError := make(chan error, 1)
	// 7.在goroutine中启动服务器
	go func() {
		log.Printf("server starting address=%s", cfg.HTTPAddress)
		// ListenAndServe 会一直阻塞 所以需要放入goroutine中
		// 如果端口被占用 错误会写进serverError
		serverError <- server.ListenAndServe()
	}()
	// 8.监听系统退出信号
	// 监听：
	// os.Interrupt    用户按下 Control + C
	// syscall.SIGTERM Docker 或服务器要求程序停止
	shutdownSignal, stop := signal.NotifyContext(
		context.Background(),
		os.Interrupt,
		syscall.SIGTERM,
	)
	// main 退出时停止监听信号 释放资源
	defer stop()
	// 9.等待服务器错误或者退出信号
	select {
	case serverErr := <-serverError:
		// 服务器启动失败，例如 8080 端口已经被占用。
		// http.ErrServerClosed 是服务器正常关闭时返回的错误，
		// 不应该当成真正的程序异常。
		if !errors.Is(serverErr, http.ErrServerClosed) {
			log.Printf("server stopped unexpected: %v:", serverErr)
		}
		// 服务器已经无法继续运行，直接结束 main。
		return
	case <-shutdownSignal.Done():
		// 收到 Control + C 或 SIGTERM。
		log.Println("shutdown signal received")
	}
	// 10.创建关闭超时Context
	// 最多给正在处理的请求 10 秒时间结束。
	shutdownContext, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// 11.优雅关闭http server
	if err := server.Shutdown(shutdownContext); err != nil {
		// shutdown失败或者超过10s
		log.Printf("graceful shutdown failed: %v", err)
		// 优雅关闭失败后强制关闭连接
		if closeError := server.Close(); closeError != nil {
			log.Printf("forced close connect: %v", closeError)
		}
	}
	log.Printf("server stopped")
}
