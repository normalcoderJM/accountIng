package auth

import (
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/normalcoderJM/accountIng/apps/api/internal/response"
	"golang.org/x/crypto/bcrypt"
)

type Handle struct {
	store *Store
}

func NewHandle(s *Store) *Handle {
	return &Handle{store: s}
}

// 注册路由
func (h *Handle) RegisterRoutes(r gin.IRouter) {
	r.POST("/auth/register", h.Register)
	r.POST("/auth/login", h.Login)
	// 登录注册不需要走中间件 其他接口都需要鉴权
	protected := r.Group("")
	// 后面挂的路由都要经过这个中间件
	protected.Use(AuthMiddleware())
	protected.GET("/auth/me", h.Me)
}

// 注册handler
func (h *Handle) Register(c *gin.Context) {
	var req RegisterRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusInternalServerError, 40001, err.Error())
		return
	}
	// 密码加密
	password, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		response.Error(c, http.StatusInternalServerError, 50001, "failed to hash password")
		return
	}
	// 创建用户
	user, err := h.store.CreateUser(c.Request.Context(), req.Email, string(password))
	if err != nil {
		fmt.Println("create user error:", err)
		response.Error(c, http.StatusInternalServerError, 50002, "failed to create user")
		return
	}
	response.Success(c, user)

}

// 登录handler
func (h *Handle) Login(c *gin.Context) {
	var req LoginRequest
	// 校验整体参数报错
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusInternalServerError, 40001, err.Error())
		return
	}
	// 根据邮箱查找用户名
	user, err := h.store.GetUserByEmail(c.Request.Context(), req.Email)
	if err != nil {
		response.Error(c, http.StatusInternalServerError, 40001, "invalid user or password")
		return
	}
	// 数据库存的密码是密文 需要和传参过来的密码对比
	fmt.Printf("%+v\n, ${user}", user)
	fmt.Printf("%+v\n, ${req}", req)
	err = bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.Password))
	if err != nil {
		response.Error(c, http.StatusInternalServerError, 40001, "invalid email or password")
		return
	}
	// 校验token
	token, err := GenerateToken(user)
	if err != nil {
		response.Error(c, http.StatusInternalServerError, 40001, "failed to generateToke")
		return
	}

	response.Success(c, LoginResponse{
		Token: token,
		User:  user,
	})

}

// 中间件鉴权
func (h *Handle) Me(c *gin.Context) {
	/* 获取userId 读取中间件set的值
	   AuthMiddleware 解析 token -> c.Set("userId", userID)
	   Me handler -> c.Get("userId") -> 查询用户
	*/
	userIdValue, exits := c.Get("userId")
	if !exits {
		response.Error(c, http.StatusUnauthorized, 40106, " missing user context")
		return
	}

	userId, ok := userIdValue.(int64)
	if !ok {
		response.Error(c, http.StatusUnauthorized, 40107, "invalid user context")
		return
	}

	user, err := h.store.GetUserById(c.Request.Context(), userId)
	if err != nil {
		response.Error(c, http.StatusUnauthorized, 40108, "user not fount")
		return
	}
	response.Success(c, user)

}
