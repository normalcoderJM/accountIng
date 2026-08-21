package auth

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/normalcoderJM/accountIng/apps/api/internal/errorcode"
	"github.com/normalcoderJM/accountIng/apps/api/internal/response"
)

// 添加中间件鉴权 识别token是否有效
func AuthMiddleware(secret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		// 判断请求头token
		if authHeader == "" {
			response.Error(c, http.StatusUnauthorized, errorcode.MissingAuthorization, "missing authorization header")
			c.Abort()
			return
		}
		parts := strings.SplitN(authHeader, " ", 2) //按空格最多切割成2部分
		// 请求头格式为Authoriazion：Bearer tokenxxx
		if len(parts) != 2 || parts[0] != "Bearer" {
			response.Error(c, http.StatusUnauthorized, errorcode.InvalidAuthorizationHeader, "invalid authorization header")
			c.Abort()
			return
		}
		// 解析jwt
		tokenString := parts[1]
		token, err := jwt.Parse(tokenString, func(t *jwt.Token) (any, error) {
			return []byte(secret), nil
		},
			jwt.WithValidMethods([]string{jwt.SigningMethodHS256.Alg()}))
		if err != nil || !token.Valid {
			response.Error(c, http.StatusUnauthorized, errorcode.InvalidToken, "invalid token")
			c.Abort()
			return
		}
		// claims是生成token时放进去的数据 email password userId 这些
		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			response.Error(c, http.StatusUnauthorized, errorcode.InvalidTokenClaims, "invalid token claims")
			c.Abort()
			return
		}
		// JWT 解析出来的数字通常是 float64 需要转换
		userIDFloat, ok := claims["userId"].(float64)
		if !ok {
			response.Error(c, http.StatusUnauthorized, errorcode.InvalidTokenUser, "invalid token user")
			c.Abort()
			return
		}
		userId := int64(userIDFloat)

		c.Set("userId", userId)
		c.Next()

	}

}
