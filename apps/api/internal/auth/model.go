package auth

import "time"

// user 泛型
type User struct {
	Id        int64     `json:"id"`
	Password  string    `json:"-"` //非明文展示
	Email     string    `json:"email"`
	CreatedAt time.Time `json:"createdAt"`
}

// 注册结构体
type RegisterRequest struct {
	Email    string `json:"email" binding:"required,email,max=254"`
	Password string `json:"password" binding:"required,min=6,max=72"`
}

// 登录结构体
type LoginRequest struct {
	Email    string `json:"email" binding:"required,email,max=254"`
	Password string `json:"password" binding:"required,min=6,max=72"`
}

// 登录响应结构体
type LoginResponse struct {
	Token string `json:"token"`
	User  User   `json:"user"`
}
