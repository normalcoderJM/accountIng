package transactions

import (
	"database/sql"
	"errors"
	"fmt"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/normalcoderJM/accountIng/apps/api/internal/response"
)

type Handle struct {
	store *Store
}

func NewHandle(store *Store) *Handle {
	return &Handle{store: store}
}

func (h *Handle) RegisterRouter(r gin.IRouter) {
	r.GET("/transactions", h.List)
	r.POST("/transactions", h.Create)
	r.PUT("/transactions/:id", h.Update)
	r.DELETE("/transactions/:id", h.Delete)
}

func (h *Handle) Create(c *gin.Context) {
	userId, ok := getUserId(c)
	if !ok {
		response.Error(c, http.StatusInternalServerError, 40107, "invalid user context")
		return
	}
	var req CreateTransactionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, 40001, "invalid transaction data")
		return
	}
	transaction, err := h.store.Create(c.Request.Context(), userId, req)
	if err != nil {
		fmt.Println("create transactions error", err)
		response.Error(c, http.StatusInternalServerError, 50001, "create transactions error")
		return
	}

	response.Success(c, transaction)

}
func (h *Handle) List(c *gin.Context) {

	userId, ok := getUserId(c)
	if !ok {
		response.Error(c, http.StatusInternalServerError, 40107, "invalid user context")
		return
	}
	transactions, err := h.store.ListByUserId(c.Request.Context(), userId)
	if err != nil {
		fmt.Println("查询用户失败", err)
		response.Error(c, http.StatusInternalServerError, 50001, "查询用户失败")
		return
	}

	response.Success(c, transactions)

}

func (h *Handle) Update(c *gin.Context) {
	userId, ok := getUserId(c)
	if !ok {
		response.Error(c, http.StatusInternalServerError, 50000, "invalid user context")
		return
	}
	id, valid := parseTransactionID(c)
	if !valid {
		return
	}
	// 转换json失败
	var req UpdateTransactionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, 40003, "invalid transaction data")
		return
	}
	transaction, err := h.store.Update(c.Request.Context(), userId, id, req)

	if err != nil {
		// errors检查数据库错误
		if errors.Is(err, sql.ErrNoRows) {
			response.Error(c, http.StatusBadRequest, 40401, "transaction not found")
			return
		}

		fmt.Println("update transaction error", err)
		response.Error(c, http.StatusInternalServerError, 50002, "failed to update transaction")
		return
	}
	response.Success(c, transaction)
}

func (h *Handle) Delete(c *gin.Context) {
	userId, ok := getUserId(c)
	if !ok {
		response.Error(c, http.StatusInternalServerError, 40107, "invalid user context")
		return
	}
	id, valid := parseTransactionID(c)
	if !valid {
		return
	}

	err := h.store.Delete(c.Request.Context(), id, userId)
	if err != nil {
		if err == sql.ErrNoRows {
			response.Error(c, http.StatusBadRequest, 40401, "transaction not fount")
			return
		}
		fmt.Println("deleted transaction error", err)
		response.Error(c, http.StatusInternalServerError, 50003, "failed to delete transaction")
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
		response.Error(c, http.StatusBadRequest, 40002, "invalid transaction id")
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
	return userId, ok
}
