package households

import (
	"context"
	"errors"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/normalcoderJM/accountIng/apps/api/internal/auth"
	"github.com/normalcoderJM/accountIng/apps/api/internal/errorcode"
	"github.com/normalcoderJM/accountIng/apps/api/internal/response"
)

type HouseholdService interface {
	Create(ctx context.Context, userId int64, request CreateHouseholdRequest) (Household, error)
	List(ctx context.Context, userId int64) ([]HouseholdListItem, error)
}

type Handle struct {
	service HouseholdService
}

func NewHandle(service HouseholdService) *Handle {
	return &Handle{service: service}
}

// RegisterRouter 注册家庭账本相关的路由 接口需要携带token 不能跳过中间件
func (h *Handle) RegisterRouter(router *gin.RouterGroup) {
	router.GET("/households", h.List)
	router.POST("/households", h.Create)
}

func (h *Handle) Create(c *gin.Context) {
	userId, ok := auth.UserIDFromContext(c)
	if !ok {
		response.Error(c, http.StatusInternalServerError, errorcode.InvalidUserContext, "用户上下文错误")
		return
	}
	var request CreateHouseholdRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		response.Error(c, http.StatusBadRequest, errorcode.InvalidHouseholdCreateData, "家庭名称不能为空，2-40字符之间")
		return
	}
	household, err := h.service.Create(c.Request.Context(), userId, request)
	if err != nil {
		if errors.Is(err, ErrInvalidHouseholdName) {
			response.Error(c, http.StatusBadRequest, errorcode.InvalidHouseholdCreateData, "家庭名称不能为空，2-40字符之间")
			return
		}

		log.Printf("create household failed: userId=%d err=%v", userId, err)

		response.Error(c, http.StatusInternalServerError, errorcode.CreateHouseholdFailed, "创建家庭账本失败，请稍后重试")
		return
	}
	response.Created(c, household)

}

func (h *Handle) List(c *gin.Context) {
	userId, ok := auth.UserIDFromContext(c)
	if !ok {
		response.Error(c, http.StatusInternalServerError, errorcode.InvalidUserContext, "用户上下文错误")
		return
	}
	items, err := h.service.List(c.Request.Context(), userId)
	if err != nil {
		log.Printf("list households failed : userId=%d err=%v", userId, err)
		response.Error(c, http.StatusInternalServerError, errorcode.ListHouseholdsFailed, "获取家庭账本失败，请稍后重试")
		return
	}
	response.Success(c, items)
}
