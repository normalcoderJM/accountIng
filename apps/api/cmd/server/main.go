package main

import (
	"fmt"

	"github.com/gin-gonic/gin"
	"github.com/normalcoderJM/accountIng/apps/api/internal/auth"
	"github.com/normalcoderJM/accountIng/apps/api/internal/db"
	"github.com/normalcoderJM/accountIng/apps/api/internal/health"
)

func main() {
	database, err := db.Open()
	authStore := auth.NewStore(database)
	authHandle := auth.NewHandle(authStore)

	r := gin.Default()
	r.GET("/health", health.Handler)

	api := r.Group("/api/v1")
	authHandle.RegisterRoutes(api)

	fmt.Println("server running on :8080")

	r.Run(":8080")

	if err != nil {
		panic(err)
	}
	defer database.Close()

	_ = database
}
