package auth

import "time"

// user 泛型
type User struct {
	// Username string    `json:"username"`
	Id       int64     `json:"id"`
	Password string    `json:"-"` //非明文展示
	Email    string    `json:"email"`
	CreateAt time.Time `json:"createAt"`
}

// 注册结构体
type RegisterRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=6"`
}

// 登录结构体
type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=6"`
}

// 登录响应结构体
type LoginResponse struct {
	Token string `json:"token"`
	User  User   `json:"user"`
}
