package health

import (
	"github.com/gin-gonic/gin"
	"github.com/normalcoderJM/accountIng/apps/api/internal/response"
)

func Handler(c *gin.Context) {

	response.Success(c, map[string]string{
		"status": "ok",
	})

}
