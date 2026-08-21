package config

import (
	"fmt"
	"os"
)

/*
	此包只负责

读取环境变量

	提供默认值
	启动前校验
	返回统一 Config
*/
type Config struct {
	HTTPAddress string
	DatabaseURL string
	JWTSecret   string
}

func Load() (Config, error) {
	cfg := Config{
		HTTPAddress: getEnv(
			"HTTP_ADDRESS",
			":8080",
		),
		DatabaseURL: os.Getenv("DATABASE_URL"),
		JWTSecret:   os.Getenv("JWT_SECRET"),
	}

	if cfg.DatabaseURL == "" {
		return Config{}, fmt.Errorf("DATABASE_URL is required")
	}
	// jwt位数必须为32位
	if len(cfg.JWTSecret) < 32 {
		return Config{}, fmt.Errorf("JWT_SECRET must contain at least 32 characters")
	}
	return cfg, nil
}

func getEnv(key string, defaultValue string) string {
	value := os.Getenv(key)

	if value == "" {
		return defaultValue
	}
	return value

}
