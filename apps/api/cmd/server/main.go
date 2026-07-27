package main

import (
	"fmt"

	"github.com/gin-gonic/gin"
	"github.com/normalcoderJM/accountIng/apps/api/internal/auth"
	"github.com/normalcoderJM/accountIng/apps/api/internal/db"
	"github.com/normalcoderJM/accountIng/apps/api/internal/health"
	"github.com/normalcoderJM/accountIng/apps/api/internal/transactions"
)

func main() {
	database, err := db.Open()
	// 鉴权
	authStore := auth.NewStore(database)
	authHandle := auth.NewHandle(authStore)
	// 账单
	transactionStore := transactions.NewStore(database)
	tansactionHandle := transactions.NewHandle(transactionStore)
	r := gin.Default()
	r.GET("/health", health.Handler)

	api := r.Group("/api/v1")
	authHandle.RegisterRoutes(api)
	// 挂载protected路由组 所有的路由都需要鉴权
	protected := api.Group("")
	protected.Use(auth.AuthMiddleware())
	tansactionHandle.RegisterRouter(protected)

	fmt.Println("server running on :8080")

	r.Run(":8080")

	if err != nil {
		panic(err)
	}
	defer database.Close()

	_ = database
}
