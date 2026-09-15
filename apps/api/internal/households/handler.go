package households

import (
	"context"
	"errors"
	"log"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/normalcoderJM/accountIng/apps/api/internal/auth"
	"github.com/normalcoderJM/accountIng/apps/api/internal/errorcode"
	"github.com/normalcoderJM/accountIng/apps/api/internal/response"
)

type HouseholdService interface {
	Create(ctx context.Context, userId int64, request CreateHouseholdRequest) (HouseholdListItem, error)
	List(ctx context.Context, userId int64) ([]HouseholdListItem, error)
	ListMembers(ctx context.Context, userId int64, householdId int64) ([]HouseholdMemberListItem, error)
	AddMember(ctx context.Context, userId int64, householdId int64, request AddHouseholdMemberRequest) (HouseholdMemberListItem, error)
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
	router.GET("/households/:householdId/members", h.ListMembers)
	router.POST("/households/:householdId/members", h.AddMember)
}

func (h *Handle) AddMember(c *gin.Context) {
	userId, ok := auth.UserIDFromContext(c)
	if !ok {
		response.Error(c, http.StatusInternalServerError, errorcode.InvalidUserContext, "用户上下文错误")
		return
	}
	householdId, err := strconv.ParseInt(c.Param("householdId"), 10, 64)
	if err != nil || householdId <= 0 {
		response.Error(c, http.StatusBadRequest, errorcode.InvalidHouseholdID, "家庭ID不正确")
		return
	}
	var request AddHouseholdMemberRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		response.Error(c, http.StatusBadRequest, errorcode.InvalidHouseholdMemberData, "请输入正确的已注册邮箱")
		return
	}

	member, err := h.service.AddMember(c.Request.Context(), userId, householdId, request)
	if err != nil {
		switch {
		case errors.Is(err, ErrInvalidMemberEmail):
			response.Error(c, http.StatusBadRequest, errorcode.InvalidHouseholdMemberData, "请输入正确的已注册邮箱")
		case errors.Is(err, ErrHouseholdNotAccessible):
			response.Error(c, http.StatusNotFound, errorcode.HouseholdNotAccessible, "家庭不存在或无权访问")
		case errors.Is(err, ErrHouseholdManageForbidden):
			response.Error(c, http.StatusForbidden, errorcode.HouseholdManageForbidden, "只有家庭拥有者或管理员可以添加成员")
		case errors.Is(err, ErrInviteeNotFound):
			response.Error(c, http.StatusNotFound, errorcode.HouseholdInviteeNotFound, "该邮箱尚未注册")
		case errors.Is(err, ErrMemberAlreadyActive):
			response.Error(c, http.StatusConflict, errorcode.HouseholdMemberAlreadyExists, "该用户已经是家庭成员")
		default:
			log.Printf("add household member failed: userId=%d householdId=%d err=%v", userId, householdId, err)
			response.Error(c, http.StatusInternalServerError, errorcode.AddHouseholdMemberFailed, "添加家庭成员失败，请稍后重试")
		}
		return
	}
	response.Created(c, member)
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

func (h *Handle) ListMembers(c *gin.Context) {
	userId, ok := auth.UserIDFromContext(c)
	if !ok {
		response.Error(c, http.StatusInternalServerError, errorcode.InvalidUserContext, "用户上下文错误")
		return
	}
	householdId, err := strconv.ParseInt(c.Param("householdId"), 10, 64)
	if err != nil || householdId <= 0 {
		response.Error(c, http.StatusBadRequest, errorcode.InvalidHouseholdID, "家庭ID不正确")
		return
	}

	members, err := h.service.ListMembers(c.Request.Context(), userId, householdId)
	if err != nil {
		if errors.Is(err, ErrHouseholdNotAccessible) {
			response.Error(c, http.StatusNotFound, errorcode.HouseholdNotAccessible, "家庭不存在或无权访问")
			return
		}
		log.Printf("list household members failed: userId=%d householdId=%d err=%v", userId, householdId, err)

		response.Error(c, http.StatusInternalServerError, errorcode.ListHouseholdMembersFailed, "获取家庭成员失败，请稍后重试")
		return
	}
	response.Success(c, members)
}
