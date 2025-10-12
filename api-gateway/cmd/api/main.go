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
	"github.com/LeonLow97/internal/core/services/user"
)

func main() {
	// Load api gateway configuration
	cfg, err := config.GetConfig()
	if err != nil {
		log.Fatalf("failed to load config with error: %v\n", err)
	}

	// Load api gateway cache
	cacheClient, err := cache.GetCache(*cfg)
	if err != nil {
		log.Fatalf("failed to load cache with error: %v\n", err)
	}

	// Load gRPC clients
	userGrpcClient, err := client.NewGrpcClient(*cfg)
	if err != nil {
		log.Fatalf("failed to create grpc client with error: %v\n", err)
	}
	defer userGrpcClient.Close()

	healthHandler := inbound.NewHealthHandler(cacheClient)

	userOutbound := outbound.NewUserOutbound(userGrpcClient.UserService())
	userService := user.NewUserService(userOutbound)
	userHandler := inbound.NewUserHandler(*cfg, userService)

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
