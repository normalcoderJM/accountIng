package response

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// 约束泛型{code:0,message:"success",data:{} || []}
type Body struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    any    `json:"data,omitempty"` //如果data为空 则不输出data omitempty
}

// 强制转换成json
func JSON(c *gin.Context, status int, body Body) {
	c.JSON(status, body)
}

// 成功的回调
func Success(c *gin.Context, data any) {
	JSON(c, http.StatusOK, Body{
		Code:    0,
		Message: "success",
		Data:    data,
	})
}

func Error(c *gin.Context, status int, code int, message string) {
	JSON(c, status, Body{
		Code:    code,
		Message: message,
	})
}
