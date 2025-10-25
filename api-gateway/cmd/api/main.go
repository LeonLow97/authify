package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/LeonLow97/internal/adapters/inbound"
	"github.com/LeonLow97/internal/adapters/outbound"
	"github.com/LeonLow97/internal/cache"
	"github.com/LeonLow97/internal/client"
	"github.com/LeonLow97/internal/config"
	user "github.com/LeonLow97/internal/core/services"
	"github.com/LeonLow97/internal/pkg/ratelimit"
)

func main() {
	// Load api gateway configuration
	cfg, err := config.GetConfig()
	if err != nil {
		log.Fatalf("failed to load config with error: %v\n", err)
	}

	// Load Redis cache client
	appCache, err := cache.NewRedisCache(*cfg)
	if err != nil {
		log.Fatalf("failed to load redis cache with error: %v\n", err)
	}

	// Load gRPC clients
	userGrpcClient, err := client.NewGrpcClient(*cfg)
	if err != nil {
		log.Fatalf("failed to create grpc client with error: %v\n", err)
	}
	defer userGrpcClient.Close()

	// Load Rate Limiters
	rateLimiter := ratelimit.NewRateLimiter(*cfg, appCache)

	healthHandler := inbound.NewHealthHandler(appCache)

	userOutbound := outbound.NewUserOutbound(userGrpcClient.UserService())
	userService := user.NewUserService(userOutbound)
	userHandler := inbound.NewUserHandler(*cfg, rateLimiter, userService)

	app := application{
		cfg:           cfg,
		HealthHandler: healthHandler,
		UserHandler:   userHandler,
	}
	router := app.registerRoutes()

	serverAddr := fmt.Sprintf("%s:%d", cfg.Server.BaseUrl, cfg.Server.Port)
	srv := &http.Server{
		Addr:    serverAddr,
		Handler: router,
	}

	// Start server in a goroutine
	go func() {
		log.Printf("Starting API Gateway | Server Address: '%s'\n", serverAddr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server failed to start: %v\n", err)
		}
	}()

	// Wait for interrupt signal (Ctrl+C, SIGTERM from k8s, etc.)
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down server gracefully...")

	// Create context with timeout for shutdown
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Attempt graceful shutdown
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}
}
