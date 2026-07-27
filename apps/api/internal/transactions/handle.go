package transactions

import (
	"fmt"
	"net/http"

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
}

func (h *Handle) Create(c *gin.Context) {
	userId, ok := getUserId(c)
	if !ok {
		response.Error(c, http.StatusInternalServerError, 40107, "invalid user context")
		return
	}
	var req CreateTransactionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusUnauthorized, 40001, err.Error())
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

func getUserId(c *gin.Context) (int64, bool) {
	values, exist := c.Get("userId")
	if !exist {
		return 0, false
	}
	userId, ok := values.(int64)
	return userId, ok
}
