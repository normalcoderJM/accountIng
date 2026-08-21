package auth

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

const testJWTSecret = "test-jwt-secret-with-at-least-32-characters"

func TestAuthMiddlewareRejectsInvalidAuthorization(t *testing.T) {

	gin.SetMode(gin.TestMode)

	tests := []struct {
		name   string
		header string
	}{
		{
			name:   "没有Authorization请求头",
			header: "",
		},
		{
			name:   "不是Bearer格式",
			header: "Basic abc123",
		},
		{
			name:   "Token内容无效",
			header: "Bearer invalid-token",
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			handlerCalled := false

			router := gin.New()

			router.GET(
				"/protected",
				AuthMiddleware(testJWTSecret),
				func(c *gin.Context) {
					handlerCalled = true
					c.Status(http.StatusOK)
				},
			)

			request := httptest.NewRequest(
				http.MethodGet,
				"/protected",
				nil,
			)

			if test.header != "" {
				request.Header.Set(
					"Authorization",
					test.header,
				)
			}

			recorder := httptest.NewRecorder()

			router.ServeHTTP(recorder, request)

			if recorder.Code != http.StatusUnauthorized {
				t.Fatalf(
					"期望状态码 %d，实际得到 %d",
					http.StatusUnauthorized,
					recorder.Code,
				)
			}

			if handlerCalled {
				t.Fatal("鉴权失败后不应该继续执行受保护接口")
			}
		})
	}
}

func TestAuthMiddlewarePassesUserIDToHandler(t *testing.T) {
	gin.SetMode(gin.TestMode)

	token, err := GenerateToken(User{
		Id:    42,
		Email: "user@example.com",
	}, testJWTSecret)
	if err != nil {
		t.Fatalf("生成测试 Token 失败: %v", err)
	}

	var receivedUserID int64

	router := gin.New()

	router.GET(
		"/protected",
		AuthMiddleware(testJWTSecret),
		func(c *gin.Context) {
			value, exists := c.Get("userId")
			if !exists {
				t.Fatal("Handler 没有收到 userId")
			}

			userID, ok := value.(int64)
			if !ok {
				t.Fatalf(
					"userId 类型错误，实际类型为 %T",
					value,
				)
			}

			receivedUserID = userID
			c.Status(http.StatusOK)
		},
	)

	request := httptest.NewRequest(
		http.MethodGet,
		"/protected",
		nil,
	)

	request.Header.Set(
		"Authorization",
		"Bearer "+token,
	)

	recorder := httptest.NewRecorder()

	router.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf(
			"期望状态码 %d，实际得到 %d，响应内容: %s",
			http.StatusOK,
			recorder.Code,
			recorder.Body.String(),
		)
	}

	if receivedUserID != 42 {
		t.Fatalf(
			"期望 userId 为 42，实际得到 %d",
			receivedUserID,
		)
	}
}
