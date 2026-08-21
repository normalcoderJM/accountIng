package auth

import (
	"context"
	"errors"
	"testing"
	"time"

	"golang.org/x/crypto/bcrypt"
)

// fakeAuthRepository 是测试用的内存 Repository。
//
// 它不会连接 PostgreSQL，只返回测试预设的数据。
type fakeAuthRepository struct {
	userByEmail      User
	userByEmailError error
}

func (f *fakeAuthRepository) CreateUser(
	ctx context.Context,
	email string,
	password string,
) (User, error) {
	return User{}, nil
}

func (f *fakeAuthRepository) GetUserByEmail(
	ctx context.Context,
	email string,
) (User, error) {
	if f.userByEmailError != nil {
		return User{}, f.userByEmailError
	}

	return f.userByEmail, nil
}

func (f *fakeAuthRepository) GetUserById(
	ctx context.Context,
	id int64,
) (User, error) {
	return User{}, nil
}

func TestServiceLoginSuccess(t *testing.T) {
	const password = "password123"

	// 模拟注册时保存到数据库的 bcrypt 密码。
	hashedPassword, err := bcrypt.GenerateFromPassword(
		[]byte(password),
		bcrypt.DefaultCost,
	)
	if err != nil {
		t.Fatalf(
			"生成测试密码哈希失败: %v",
			err,
		)
	}

	repository := &fakeAuthRepository{
		userByEmail: User{
			Id:       10,
			Email:    "test@example.com",
			Password: string(hashedPassword),
		},
	}

	service := NewService(
		repository,
		"test-jwt-secret-with-at-least-32-characters",
		time.Second,
	)

	result, err := service.Login(
		context.Background(),
		"test@example.com",
		password,
	)
	if err != nil {
		t.Fatalf(
			"正确账号密码不应该登录失败: %v",
			err,
		)
	}

	if result.Token == "" {
		t.Fatal("登录成功后 Token 不应该为空")
	}

	if result.User.Id != 10 {
		t.Fatalf(
			"期望用户 ID 为 10，实际得到 %d",
			result.User.Id,
		)
	}

	if result.User.Email != "test@example.com" {
		t.Fatalf(
			"期望邮箱为 test@example.com，实际得到 %s",
			result.User.Email,
		)
	}
}

func TestServiceLoginWrongPassword(t *testing.T) {
	hashedPassword, err := bcrypt.GenerateFromPassword(
		[]byte("correct-password"),
		bcrypt.DefaultCost,
	)
	if err != nil {
		t.Fatalf(
			"生成测试密码哈希失败: %v",
			err,
		)
	}

	repository := &fakeAuthRepository{
		userByEmail: User{
			Id:       10,
			Email:    "test@example.com",
			Password: string(hashedPassword),
		},
	}

	service := NewService(
		repository,
		"test-jwt-secret-with-at-least-32-characters",
		time.Second,
	)

	_, err = service.Login(
		context.Background(),
		"test@example.com",
		"wrong-password",
	)

	if !errors.Is(err, ErrInvalidCredentials) {
		t.Fatalf(
			"错误密码应该返回 ErrInvalidCredentials，实际得到: %v",
			err,
		)
	}
}
