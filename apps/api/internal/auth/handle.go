package auth

import (
	"context"
	"errors"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/normalcoderJM/accountIng/apps/api/internal/errorcode"
	"github.com/normalcoderJM/accountIng/apps/api/internal/response"
)

// AuthService 定义 Handler 需要的认证业务。
//
// Handler 依赖接口，不依赖具体的 *Service。
type AuthService interface {
	Register(
		ctx context.Context,
		email string,
		password string,
	) (LoginResponse, error)

	Login(
		ctx context.Context,
		email string,
		password string,
	) (LoginResponse, error)

	CurrentUser(
		ctx context.Context,
		userID int64,
	) (User, error)
}

type Handle struct {
	service   AuthService
	jwtSecret string
}

func NewHandle(service AuthService, jwtSecret string) *Handle {
	return &Handle{service: service, jwtSecret: jwtSecret}
}

// 注册路由
func (h *Handle) RegisterRoutes(r gin.IRouter) {
	r.POST("/auth/register", h.Register)
	r.POST("/auth/login", h.Login)
	// 登录注册不需要走中间件 其他接口都需要鉴权
	protected := r.Group("")
	// 后面挂的路由都要经过这个中间件
	protected.Use(AuthMiddleware(h.jwtSecret))
	protected.GET("/auth/me", h.Me)
}

// 注册handler
func (h *Handle) Register(c *gin.Context) {
	var req RegisterRequest
	// JSON 格式错误、邮箱格式错误、密码长度不够，
	// 都属于客户端提交的数据不合法，应该返回 400。
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, errorcode.InvalidRegisterData, "注册信息格式不正确")
		return
	}

	// 创建用户
	result, err := h.service.Register(c.Request.Context(), req.Email, req.Password)
	if err != nil {
		if errors.Is(err, ErrPasswordTooLong) {
			response.Error(c, http.StatusBadRequest, errorcode.InvalidRegisterData, "密码过长，最多 72 字节")
			return
		}
		// 邮箱是否重复注册
		if errors.Is(err, ErrEmailAlreadyRegistered) {
			response.Error(c, http.StatusConflict, errorcode.EmailAlreadyRegistered, "邮箱已注册")
			return
		}
		// 其他数据库错误记录到服务端日志，
		// 不能把原始数据库错误直接返回给用户。
		log.Printf("create user failed:%v", err)
		response.Error(c, http.StatusInternalServerError, errorcode.CreateUserFailed, "注册失败，请稍后再试")
		return
	}
	response.Created(c, result)

}

// 登录handler Login 校验邮箱和密码，成功后签发 JWT
func (h *Handle) Login(c *gin.Context) {
	var req LoginRequest
	// // 请求参数校验失败属于 400。
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, errorcode.InvalidLoginData, "登录信息格式不正确")
		return
	}
	// 根据邮箱查找用户名
	result, err := h.service.Login(c.Request.Context(), req.Email, req.Password)
	if err != nil {
		if errors.Is(err, ErrPasswordTooLong) {
			response.Error(c, http.StatusBadRequest, errorcode.InvalidLoginData, "密码过长，最多 72 字节")
			return
		}
		if errors.Is(err, ErrInvalidCredentials) {
			// 不告诉客户端究竟是邮箱不存在还是密码错误，
			// 避免别人利用接口探测哪些邮箱已经注册。
			response.Error(c, http.StatusUnauthorized, errorcode.InvalidCredentials, "邮箱或密码错误")
			return
		}
		log.Printf("login failed:%v", err)
		response.Error(c, http.StatusInternalServerError, errorcode.QueryLoginUserFailed, "登录失败，请稍后再试")
		return

	}

	response.Success(c, result)

}

// 中间件鉴权 Me 返回当前已登录用户的信息。
func (h *Handle) Me(c *gin.Context) {
	/* 获取userId 读取中间件set的值
	   AuthMiddleware 解析 token -> c.Set("userId", userID)
	   Me handler -> c.Get("userId") -> 查询用户
	*/
	userIdValue, exits := c.Get("userId")
	if !exits {
		// 路由已经经过 AuthMiddleware，
		// 此时没有 userId 表示服务端中间件配置有问题。
		response.Error(c, http.StatusInternalServerError, errorcode.MissingUserContext, "用户上下文不存在")
		return
	}

	userId, ok := userIdValue.(int64)
	if !ok || userId <= 0 {
		response.Error(c, http.StatusInternalServerError, errorcode.InvalidUserContext, "用户上下文不正确")
		return
	}

	user, err := h.service.CurrentUser(c.Request.Context(), userId)
	if err != nil {
		if errors.Is(err, ErrCurrentUserNotFound) {
			response.Error(c, http.StatusUnauthorized, errorcode.CurrentUserNotFound, "登录状态已失效")
			return
		}
		log.Printf("query user failed:%v", err)
		response.Error(c, http.StatusInternalServerError, errorcode.QueryCurrentUserFailed, "获取用户状态失败")
		return
	}
	response.Success(c, user)

}
