package auth

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"
)

// Auth Service 对外返回的业务错误。
//
// Handler 后续通过 errors.Is() 判断错误类型，
// 再决定返回 401、409 或 500。
var (
	ErrEmailAlreadyRegistered = errors.New("email already registered")
	ErrInvalidCredentials     = errors.New("invalid credentials")
	ErrCurrentUserNotFound    = errors.New("current user not found")
	ErrPasswordTooLong        = errors.New("password exceeds bcrypt byte limit")
)

const maxPasswordBytes = 72

// Repository 定义 Auth Service 需要的数据操作。
//
// 现有的 *Store 已经实现了这些方法，
// 因此自动满足 Repository 接口。
type Repository interface {
	CreateUser(ctx context.Context, email string, password string) (User, error)
	GetUserByEmail(ctx context.Context, email string) (User, error)
	GetUserById(ctx context.Context, id int64) (User, error)
}

// service负责注册 登录和当前用户业务
type Service struct {
	repository       Repository
	jwtSecret        string
	operationTimeout time.Duration
}

// newService创建Auth service
func NewService(
	repository Repository,
	jwtSecret string,
	operationTimeout time.Duration,
) *Service {
	return &Service{
		repository:       repository,
		jwtSecret:        jwtSecret,
		operationTimeout: operationTimeout,
	}
}

func (s *Service) Register(ctx context.Context, email string, password string) (LoginResponse, error) {
	if len([]byte(password)) > maxPasswordBytes {
		return LoginResponse{}, ErrPasswordTooLong
	}

	// 邮箱去掉空格统一转成小写 避免Test@qq.com和test@qq.com被当成两个账户
	normalizedEmail := strings.ToLower(strings.TrimSpace(email))
	// 密码只能用于生成哈希 不能记录日志
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return LoginResponse{}, fmt.Errorf("hash password: %w", err)
	}
	operationContext, cancel := context.WithTimeout(ctx, s.operationTimeout)
	defer cancel()

	user, err := s.repository.CreateUser(
		operationContext, normalizedEmail, string(hashedPassword),
	)
	if err != nil {
		if IsDuplicateEmail(err) {
			return LoginResponse{}, ErrEmailAlreadyRegistered
		}
		return LoginResponse{}, fmt.Errorf("create user: %w", err)
	}

	token, err := GenerateToken(user, s.jwtSecret)
	if err != nil {
		return LoginResponse{}, fmt.Errorf("generate registration token: %w", err)
	}

	return LoginResponse{Token: token, User: user}, nil
}

func (s *Service) Login(ctx context.Context, email string, password string) (LoginResponse, error) {
	if len([]byte(password)) > maxPasswordBytes {
		return LoginResponse{}, ErrPasswordTooLong
	}

	normalizedEmail := strings.ToLower(strings.TrimSpace(email))

	operationContext, cancel := context.WithTimeout(ctx, s.operationTimeout)
	defer cancel()

	user, err := s.repository.GetUserByEmail(operationContext, normalizedEmail)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			// 邮箱不存在和密码不对返回同一个错误 防止接口泄漏某个邮箱是否已经注册
			return LoginResponse{}, ErrInvalidCredentials
		}
		return LoginResponse{}, fmt.Errorf("query user by email %w", err)
	}

	err = bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(password))
	if err != nil {
		if errors.Is(err, bcrypt.ErrMismatchedHashAndPassword) {
			return LoginResponse{}, ErrInvalidCredentials
		}
		// 如果数据库里的密码不是合法 bcrypt 哈希，
		// 这是服务端数据问题，不应该伪装成密码错误。
		return LoginResponse{}, fmt.Errorf("compare password %w", err)
	}
	token, err := GenerateToken(user, s.jwtSecret)
	if err != nil {
		return LoginResponse{}, fmt.Errorf("generate token %w", err)
	}
	return LoginResponse{
		Token: token, User: user,
	}, nil
}

// currentUser 获取当前登录用户
func (s *Service) CurrentUser(ctx context.Context, userId int64) (User, error) {
	operationContex, cancel := context.WithTimeout(ctx, s.operationTimeout)
	defer cancel()

	user, err := s.repository.GetUserById(operationContex, userId)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return User{}, ErrCurrentUserNotFound
		}
		return User{}, fmt.Errorf("query user %w", err)
	}
	return user, nil
}
