package auth

import (
	"time"

	"github.com/golang-jwt/jwt/v5"
)

var jwtSecret = []byte("dev-secret-accounting")

// 生成token
func GenerateToken(user User) (string, error) {
	claims := jwt.MapClaims{
		"userId": user.Id,
		"email":  user.Email,
		"exp":    time.Now().Add(24 * time.Hour).Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)

	return token.SignedString(jwtSecret)

}
