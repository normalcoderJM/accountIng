package transactions

import (
	"context"
	"database/sql"
	"errors"
	"log"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/normalcoderJM/accountIng/apps/api/internal/auth"
	"github.com/normalcoderJM/accountIng/apps/api/internal/errorcode"
	"github.com/normalcoderJM/accountIng/apps/api/internal/households"
	"github.com/normalcoderJM/accountIng/apps/api/internal/response"
)

type TransactionService interface {
	Create(ctx context.Context, userId int64, householdId int64, req CreateTransactionRequest) (Transaction, error)
	ListPage(ctx context.Context, userId int64, householdId int64, req ListTransactionsQuery) (TransactionPage, error)
	Update(ctx context.Context, userId int64, householdId int64, id int64, req UpdateTransactionRequest) (Transaction, error)
	Delete(ctx context.Context, userId int64, householdId int64, id int64) error
	Summary(ctx context.Context, userId int64, householdId int64, query SummaryTransactionsQuery) (TransactionSummary, error)
}

// Handle 只负责 HTTP 请求和响应。
type Handle struct {
	service TransactionService
}

// NewHandle 创建账单 HTTP Handler。
func NewHandle(service TransactionService) *Handle {
	return &Handle{service: service}
}

// householdID放在路径中 账单统一属于一个家庭
func (h *Handle) RegisterRouter(r gin.IRouter) {
	r.GET("/households/:householdId/transactions", h.List)
	r.GET("/households/:householdId/transactions/summary", h.Summary)
	r.POST("/households/:householdId/transactions", h.Create)
	r.PUT("/households/:householdId/transactions/:transactionId", h.Update)
	r.DELETE("/households/:householdId/transactions/:transactionId", h.Delete)
}

func (h *Handle) Create(c *gin.Context) {
	userId, ok := auth.UserIDFromContext(c)
	if !ok {
		response.Error(c, http.StatusInternalServerError, errorcode.InvalidUserContext, "用户上下文错误")
		return
	}
	householdId, ok := parseHouseholdID(c)
	if !ok {
		return
	}

	var req CreateTransactionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, errorcode.InvalidTransactionCreateData, "账单信息格式不正确")
		return
	}
	transaction, err := h.service.Create(c.Request.Context(), userId, householdId, req)
	if err != nil {
		if respondHouseholdAccessError(c, err) {
			return
		}
		if errors.Is(err, sql.ErrNoRows) {
			response.Error(c, http.StatusNotFound, errorcode.HouseholdNotAccessible, "家庭不存在或无法访问")
			return
		}
		log.Printf("create transactions error:%v", err)
		response.Error(c, http.StatusInternalServerError, errorcode.CreateTransactionFailed, "create transactions error")
		return
	}

	response.Created(c, transaction)

}
func (h *Handle) List(c *gin.Context) {

	userId, ok := auth.UserIDFromContext(c)
	if !ok {
		response.Error(c, http.StatusInternalServerError, errorcode.InvalidUserContext, "用户上下文错误")
		return
	}
	householdId, ok := parseHouseholdID(c)
	if !ok {
		return
	}
	var query ListTransactionsQuery
	if err := c.ShouldBindQuery(&query); err != nil {
		response.Error(c, http.StatusBadRequest, errorcode.InvalidTransactionListQuery, "分页参数不正确")
		return
	}
	page, err := h.service.ListPage(c.Request.Context(), userId, householdId, query)
	if err != nil {
		if errors.Is(err, ErrInvalidTransactionCursor) || errors.Is(err, ErrInvalidTransactionPeriod) {
			response.Error(c, http.StatusBadRequest, errorcode.InvalidTransactionListQuery, "分页参数不正确")
			return
		}
		if respondHouseholdAccessError(c, err) {
			return
		}
		response.Error(c, http.StatusInternalServerError, errorcode.ListTransactionsFailed, "获取账单列表失败，请稍后重试")
		return
	}

	response.Success(c, page)

}

func (h *Handle) Summary(c *gin.Context) {
	userId, ok := auth.UserIDFromContext(c)
	if !ok {
		response.Error(c, http.StatusInternalServerError, errorcode.InvalidUserContext, "用户上下文错误")
		return
	}
	householdId, ok := parseHouseholdID(c)
	if !ok {
		return
	}
	var query SummaryTransactionsQuery

	if err := c.ShouldBindQuery(&query); err != nil {
		response.Error(c, http.StatusBadRequest, errorcode.InvalidTransactionSummaryQuery, "汇总时间范围不正确")
		return
	}

	summary, err := h.service.Summary(
		c.Request.Context(), userId, householdId, query,
	)
	if err != nil {
		if errors.Is(err, ErrInvalidTransactionPeriod) {
			response.Error(c, http.StatusBadRequest, errorcode.InvalidTransactionSummaryQuery, "汇总时间范围不正确")
			return
		}
		if respondHouseholdAccessError(c, err) {
			return
		}
		log.Printf("summary transactions failed:%v", err)
		response.Error(c, http.StatusInternalServerError, errorcode.SummaryTransactionsFailed, "获取账单汇总失败，请稍后再试")
		return
	}
	response.Success(c, summary)
}

func (h *Handle) Update(c *gin.Context) {
	userId, ok := auth.UserIDFromContext(c)
	if !ok {
		response.Error(c, http.StatusInternalServerError, errorcode.InvalidUserContext, "用户上下文错误")
		return
	}
	id, valid := parseTransactionID(c)
	if !valid {
		return
	}
	householdId, ok := parseHouseholdID(c)
	if !ok {
		return
	}
	// 转换json失败
	var req UpdateTransactionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, errorcode.InvalidTransactionUpdateData, "账单格式不正确")
		return
	}
	transaction, err := h.service.Update(c.Request.Context(), userId, householdId, id, req)

	if err != nil {
		if respondHouseholdAccessError(c, err) {
			return
		}
		// errors检查数据库错误
		if errors.Is(err, sql.ErrNoRows) {
			response.Error(c, http.StatusNotFound, errorcode.TransactionNotFound, "账单不存在")
			return
		}

		log.Printf("update transaction error:%v", err)
		response.Error(c, http.StatusInternalServerError, errorcode.UpdateTransactionFailed, "failed to update transaction")
		return
	}
	response.Success(c, transaction)
}

func (h *Handle) Delete(c *gin.Context) {
	userId, ok := auth.UserIDFromContext(c)
	if !ok {
		response.Error(c, http.StatusInternalServerError, errorcode.InvalidUserContext, "用户上下文错误")
		return
	}
	id, valid := parseTransactionID(c)
	if !valid {
		return
	}
	householdId, ok := parseHouseholdID(c)
	if !ok {
		return
	}

	err := h.service.Delete(c.Request.Context(), userId, householdId, id)
	if err != nil {
		if respondHouseholdAccessError(c, err) {
			return
		}

		if errors.Is(err, sql.ErrNoRows) {
			response.Error(c, http.StatusNotFound, errorcode.TransactionNotFound, "账单不存在")
			return
		}
		log.Printf("deleted transaction error:%v", err)
		response.Error(c, http.StatusInternalServerError, errorcode.DeleteTransactionFailed, "删除账单失败，请稍后重试")
		return
	}
	response.Success(
		c, gin.H{
			"deleted": true,
		},
	)
}

// 解析URl中的家庭id
func parseHouseholdID(c *gin.Context) (int64, bool) {
	householdId, err := strconv.ParseInt(c.Param("householdId"), 10, 64)
	if err != nil || householdId <= 0 {
		response.Error(c, http.StatusBadRequest, errorcode.InvalidHouseholdID, "家庭ID不正确")
		return 0, false
	}
	return householdId, true
}

// 解析url中的账单id
func parseTransactionID(c *gin.Context) (int64, bool) {
	transactionId, err := strconv.ParseInt(c.Param("transactionId"), 10, 64)
	if err != nil || transactionId <= 0 {
		response.Error(c, http.StatusBadRequest, errorcode.InvalidTransactionID, "账单ID不正确")
		return 0, false
	}
	return transactionId, true
}

// 统一处理家庭权限错误 返回true 表示错误已经转换成http响应 调用者必须立即return
func respondHouseholdAccessError(c *gin.Context, err error) bool {
	switch {
	case errors.Is(err, households.ErrHouseholdNotAccessible):
		response.Error(c, http.StatusNotFound, errorcode.HouseholdNotAccessible, "家庭不存在或无权访问")
		return true
	case errors.Is(err, households.ErrHouseholdReadOnly):
		response.Error(c, http.StatusForbidden, errorcode.HouseholdReadOnly, "当前家庭角色只有查看权限")
		return true
	default:
		return false
	}
}
