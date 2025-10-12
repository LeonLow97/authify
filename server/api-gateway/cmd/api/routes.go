package main

import (
	"net/http"

	"github.com/LeonLow97/internal/pkg/middleware"
	"github.com/gin-gonic/gin"
)

func (app *application) routes() *gin.Engine {
	// Application Middlewares to process incoming requests
	middleware := middleware.NewMiddleware(*app.cfg, app.AppCache)

	router := gin.Default()

	// Perform healthcheck endpoint to check if service is healthy and running
	router.GET("/healthcheck", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "OK", "message": "api gateway healthy and running!"})
	})

	router.Use(middleware.IPWhitelistingMiddleware())
	router.Use(middleware.JWTAuthMiddleware())
	// router.Use(middleware.RateLimitingMiddleware())

	// Authentication Microservice Endpoints
	router.POST("/login", app.AuthHandler.Login())
	router.POST("/signup", app.AuthHandler.SignUp())
	router.POST("/logout", app.AuthHandler.Logout())
	router.GET("/users", app.UserHandler.GetUsers())
	router.PATCH("/user", app.UserHandler.UpdateUser())

	// Inventory Microservice Endpoints
	inventoryServiceRouter := router.Group("/inventory")
	inventoryServiceRouter.GET("/products", app.InventoryHandler.GetProducts())
	inventoryServiceRouter.GET("/product/:id", app.InventoryHandler.GetProductByID())
	inventoryServiceRouter.POST("/product", app.InventoryHandler.CreateProduct())
	inventoryServiceRouter.PATCH("/product/:id", app.InventoryHandler.UpdateProduct())
	inventoryServiceRouter.DELETE("/product/:id", app.InventoryHandler.DeleteProduct())

	// Order Microservice Endpoints
	orderServiceRouter := router.Group("")
	orderServiceRouter.GET("/orders", app.OrderHandler.GetOrders())
	orderServiceRouter.GET("/order/:id", app.OrderHandler.GetOrder())
	orderServiceRouter.POST("/order", app.OrderHandler.CreateOrder())

	return router
}
