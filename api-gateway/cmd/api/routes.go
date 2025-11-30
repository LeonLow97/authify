package main

import (
	"github.com/LeonLow97/internal/adapters/inbound"
	"github.com/LeonLow97/internal/config"
	"github.com/LeonLow97/internal/metrics"
	"github.com/LeonLow97/internal/pkg/middleware"
	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

type application struct {
	cfg           *config.Config
	HealthHandler *inbound.HealthHandler
	UserHandler   *inbound.UserHandler
}

func (app *application) registerRoutes() *gin.Engine {
	router := gin.Default()
	m := middleware.NewMiddleware(app.cfg)

	// Register middlewares
	router.Use(m.MetricsMiddleware())

	// Health Check endpoint
	healthGroup := router.Group("/health")
	healthGroup.GET("/liveness", app.HealthHandler.Liveness)
	healthGroup.GET("/readiness", app.HealthHandler.Readiness)

	// Metrics
	router.GET("/metrics", gin.WrapH(promhttp.HandlerFor(metrics.Registry, promhttp.HandlerOpts{})))

	// User Microservice
	userGroup := router.Group("/api/v1")
	userGroup.POST("/login", app.UserHandler.Login)
	userGroup.POST("/signup", app.UserHandler.SignUp)

	return router
}
