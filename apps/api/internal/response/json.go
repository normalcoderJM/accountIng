package response

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/normalcoderJM/accountIng/apps/api/internal/errorcode"
)

// 约束泛型{code:0,message:"success",data:{} || []}
type Body struct {
	Code    errorcode.Code `json:"code"`
	Message string         `json:"message"`
	Data    any            `json:"data,omitempty"` //如果data为空 则不输出data omitempty
}

// 强制转换成json
func JSON(c *gin.Context, status int, body Body) {
	c.JSON(status, body)
}

// 成功的回调
func Success(c *gin.Context, data any) {
	JSON(c, http.StatusOK, Body{
		Code:    errorcode.Success,
		Message: "success",
		Data:    data,
	})
}

func Error(c *gin.Context, status int, code errorcode.Code, message string) {
	JSON(c, status, Body{
		Code:    code,
		Message: message,
	})
}

// created 返回http 201 创建家庭 创建账号这类接口 使用201 比统一返回200 更符合RESTAPI语义
func Created(c *gin.Context, data any) {
	JSON(c, http.StatusCreated, Body{
		Code:    errorcode.Success,
		Message: "success",
		Data:    data,
	})
}
