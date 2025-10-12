package main

import (
	"net/http"

	"github.com/LeonLow97/internal/adapters/inbound/web"
	grpcclient "github.com/LeonLow97/internal/adapters/outbound/grpc"
	"github.com/LeonLow97/internal/config"
	"github.com/LeonLow97/internal/pkg/cache"
	"github.com/gin-gonic/gin"
)

type application struct {
	cfg         *config.Config
	GRPCClient  grpcclient.GRPCClient
	AppCache    cache.Cache
	UserHandler *web.UserHandler
}

func (app *application) routes() *gin.Engine {
	router := gin.Default()

	// Healthcheck endpoint for Kubernetes liveness and readiness probes
	router.GET("/healthcheck", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "OK", "message": "api gateway healthy and running!"})
	})

	// Application Middlewares to process incoming requests
	// middleware := middleware.NewMiddleware(*app.cfg, app.AppCache)

	// router.Use(middleware.IPWhitelistingMiddleware())
	// router.Use(middleware.JWTAuthMiddleware())
	// router.Use(middleware.RateLimitingMiddleware())

	// Authentication Microservice Endpoints
	router.POST("/login", app.UserHandler.Login())
	// router.POST("/signup", app.UserHandler.SignUp())
	// router.POST("/logout", app.UserHandler.Logout())
	// router.GET("/users", app.UserHandler.GetUsers())
	// router.PATCH("/user", app.UserHandler.UpdateUser())

	return router
}
