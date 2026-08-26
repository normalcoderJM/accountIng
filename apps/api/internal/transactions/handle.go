package transactions

import (
	"context"
	"database/sql"
	"errors"
	"log"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/normalcoderJM/accountIng/apps/api/internal/errorcode"
	"github.com/normalcoderJM/accountIng/apps/api/internal/response"
)

type TransactionService interface {
	Create(ctx context.Context, userId int64, req CreateTransactionRequest) (Transaction, error)
	ListPage(ctx context.Context, userId int64, req ListTransactionsQuery) (TransactionPage, error)
	Update(ctx context.Context, userId int64, id int64, req UpdateTransactionRequest) (Transaction, error)
	Delete(ctx context.Context, userId int64, id int64) error
	Summary(ctx context.Context, userId int64, query SummaryTransactionsQuery) (TransactionSummary, error)
}

// Handle 只负责 HTTP 请求和响应。
type Handle struct {
	service TransactionService
}

// NewHandle 创建账单 HTTP Handler。
func NewHandle(service TransactionService) *Handle {
	return &Handle{service: service}
}

func (h *Handle) RegisterRouter(r gin.IRouter) {
	r.GET("/transactions", h.List)
	r.GET("/transactions/summary", h.Summary)
	r.POST("/transactions", h.Create)
	r.PUT("/transactions/:id", h.Update)
	r.DELETE("/transactions/:id", h.Delete)
}

func (h *Handle) Create(c *gin.Context) {
	userId, ok := getUserId(c)
	if !ok {
		response.Error(c, http.StatusInternalServerError, errorcode.InvalidUserContext, "用户上下文错误")
		return
	}
	var req CreateTransactionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, errorcode.InvalidTransactionCreateData, "账单信息格式不正确")
		return
	}
	transaction, err := h.service.Create(c.Request.Context(), userId, req)
	if err != nil {
		log.Printf("create transactions error:%v", err)
		response.Error(c, http.StatusInternalServerError, errorcode.CreateTransactionFailed, "create transactions error")
		return
	}

	response.Success(c, transaction)

}
func (h *Handle) List(c *gin.Context) {

	userId, ok := getUserId(c)
	if !ok {
		response.Error(c, http.StatusInternalServerError, errorcode.InvalidUserContext, "用户上下文错误")
		return
	}
	var query ListTransactionsQuery
	if err := c.ShouldBindQuery(&query); err != nil {
		response.Error(c, http.StatusBadRequest, errorcode.InvalidTransactionListQuery, "分页参数不正确")
		return
	}
	page, err := h.service.ListPage(c.Request.Context(), userId, query)
	if err != nil {
		if errors.Is(err, ErrInvalidTransactionCursor) || errors.Is(err, ErrInvalidTransactionPeriod) {
			response.Error(c, http.StatusBadRequest, errorcode.InvalidTransactionListQuery, "分页参数不正确")
			return
		}
		response.Error(c, http.StatusInternalServerError, errorcode.ListTransactionsFailed, "获取账单列表失败，请稍后重试")
		return
	}

	response.Success(c, page)

}

func (h *Handle) Summary(c *gin.Context) {
	userId, ok := getUserId(c)
	if !ok {
		response.Error(c, http.StatusInternalServerError, errorcode.InvalidUserContext, "用户上下文错误")
		return
	}
	var query SummaryTransactionsQuery

	if err := c.ShouldBindQuery(&query); err != nil {
		response.Error(c, http.StatusBadRequest, errorcode.InvalidTransactionSummaryQuery, "汇总时间范围不正确")
		return
	}

	summary, err := h.service.Summary(
		c.Request.Context(), userId, query,
	)
	if err != nil {
		if errors.Is(err, ErrInvalidTransactionPeriod) {
			response.Error(c, http.StatusBadRequest, errorcode.InvalidTransactionSummaryQuery, "汇总时间范围不正确")
			return
		}
		log.Printf("summary transactions failed:%v", err)
		response.Error(c, http.StatusInternalServerError, errorcode.SummaryTransactionsFailed, "获取账单汇总失败，请稍后再试")
		return
	}
	response.Success(c, summary)
}

func (h *Handle) Update(c *gin.Context) {
	userId, ok := getUserId(c)
	if !ok {
		response.Error(c, http.StatusInternalServerError, errorcode.InvalidUserContext, "用户上下文错误")
		return
	}
	id, valid := parseTransactionID(c)
	if !valid {
		return
	}
	// 转换json失败
	var req UpdateTransactionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, errorcode.InvalidTransactionUpdateData, "账单格式不正确")
		return
	}
	transaction, err := h.service.Update(c.Request.Context(), userId, id, req)

	if err != nil {
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
	userId, ok := getUserId(c)
	if !ok {
		response.Error(c, http.StatusInternalServerError, errorcode.InvalidUserContext, "用户上下文错误")
		return
	}
	id, valid := parseTransactionID(c)
	if !valid {
		return
	}

	err := h.service.Delete(c.Request.Context(), userId, id)
	if err != nil {
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

// 解析账单id 针对账单id为-1或0的校验
func parseTransactionID(c *gin.Context) (int64, bool) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil || id <= 0 {
		response.Error(c, http.StatusBadRequest, errorcode.InvalidTransactionID, "账单ID不正确")
		return 0, false
	}
	return id, true

}

func getUserId(c *gin.Context) (int64, bool) {
	values, exist := c.Get("userId")
	if !exist {
		return 0, false
	}
	userId, ok := values.(int64)
	if !ok || userId <= 0 {
		return 0, false
	}
	return userId, ok
}
