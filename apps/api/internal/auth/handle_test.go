package auth

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

type fakeAuthService struct {
	registerResult LoginResponse
	registerError  error
	registerCalled bool
}

func (f *fakeAuthService) Register(
	ctx context.Context,
	email string,
	password string,
) (LoginResponse, error) {
	f.registerCalled = true
	return f.registerResult, f.registerError
}

func (f *fakeAuthService) Login(
	ctx context.Context,
	email string,
	password string,
) (LoginResponse, error) {
	return LoginResponse{}, nil
}

func (f *fakeAuthService) CurrentUser(
	ctx context.Context,
	userID int64,
) (User, error) {
	return User{}, nil
}

func TestRegisterReturnsCreatedSession(t *testing.T) {
	gin.SetMode(gin.TestMode)
	service := &fakeAuthService{
		registerResult: LoginResponse{
			Token: "new-token",
			User:  User{Id: 12, Email: "new@example.com"},
		},
	}
	handle := NewHandle(service, testJWTSecret)
	router := gin.New()
	router.POST("/auth/register", handle.Register)

	body := bytes.NewBufferString(
		`{"email":"new@example.com","password":"password123"}`,
	)
	request := httptest.NewRequest(http.MethodPost, "/auth/register", body)
	request.Header.Set("Content-Type", "application/json")
	recorder := httptest.NewRecorder()
	router.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusCreated {
		t.Fatalf(
			"期望状态码 %d，实际得到 %d，响应内容: %s",
			http.StatusCreated,
			recorder.Code,
			recorder.Body.String(),
		)
	}

	var responseBody struct {
		Code int `json:"code"`
		Data struct {
			Token string `json:"token"`
			User  User   `json:"user"`
		} `json:"data"`
	}
	if err := json.Unmarshal(recorder.Body.Bytes(), &responseBody); err != nil {
		t.Fatalf("注册响应不是合法 JSON: %v", err)
	}
	if responseBody.Code != 0 ||
		responseBody.Data.Token != "new-token" ||
		responseBody.Data.User.Email != "new@example.com" {
		t.Fatalf("注册响应内容不正确: %+v", responseBody)
	}
}

func TestRegisterRejectsInvalidRequestBeforeCallingService(t *testing.T) {
	gin.SetMode(gin.TestMode)
	service := &fakeAuthService{}
	handle := NewHandle(service, testJWTSecret)
	router := gin.New()
	router.POST("/auth/register", handle.Register)

	body := bytes.NewBufferString(`{"email":"not-an-email","password":"123"}`)
	request := httptest.NewRequest(http.MethodPost, "/auth/register", body)
	request.Header.Set("Content-Type", "application/json")
	recorder := httptest.NewRecorder()
	router.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("期望状态码 %d，实际得到 %d", http.StatusBadRequest, recorder.Code)
	}
	if service.registerCalled {
		t.Fatal("参数校验失败时不应该调用 Service")
	}
}
