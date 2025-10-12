package main

import (
	"github.com/LeonLow97/internal/adapters/inbound"
	"github.com/LeonLow97/internal/config"
	"github.com/gin-gonic/gin"
)

type application struct {
	cfg           *config.Config
	HealthHandler *inbound.HealthHandler
	UserHandler   *inbound.UserHandler
}

func (app *application) registerRoutes() *gin.Engine {
	router := gin.Default()

	// Health Check endpoint
	healthGroup := router.Group("/health")
	healthGroup.GET("/liveness", app.HealthHandler.Liveness)
	healthGroup.GET("/readiness", app.HealthHandler.Readiness)

	// User Microservice
	userGroup := router.Group("/api/v1")
	userGroup.POST("/login", app.UserHandler.Login)

	return router
}
