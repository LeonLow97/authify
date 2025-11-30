package main

import (
	"log"
	"os"
	"os/signal"
	"syscall"

	_ "github.com/golang-migrate/migrate/v4/source/file"

	"github.com/LeonLow97/internal/adapters/outbound"
	"github.com/LeonLow97/internal/cache"
	"github.com/LeonLow97/internal/core/services"
	"github.com/LeonLow97/internal/database"
	"github.com/LeonLow97/internal/grpcserver"
	"github.com/LeonLow97/internal/pkg/config"
)

func main() {
	// Load user microservice configuration
	cfg, err := config.GetConfig()
	if err != nil {
		log.Fatalf("failed to load config with error: %v\n", err)
	}

	// Load Redis cache client
	appCache, err := cache.NewRedisCache(*cfg)
	if err != nil {
		log.Fatalf("failed to load redis cache with error: %v\n", err)
	}

	// Get database connection
	dbClient, err := database.GetDB(*cfg)
	if err != nil {
		log.Fatalf("failed to connect to database with error: %v\n", err)
	}

	// Initialise outbound clients and services
	outboundClient := outbound.NewOutbound(dbClient.DB)
	service := services.NewService(*cfg, outboundClient, appCache)

	app := grpcserver.Application{
		Config:  *cfg,
		Service: service,
	}

	grpcDone := make(chan struct{})
	go func() {
		app.InitiateGRPCServer()
		close(grpcDone)
	}()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	select {
	case sig := <-sigCh:
		log.Printf("[MAIN] Shutdown signal received: %v", sig)
	case <-grpcDone:
		log.Println("[MAIN] gRPC server exited")
	}

	if err := dbClient.Close(); err != nil {
		log.Printf("[MAIN] Error closing database: %v", err)
	}

	log.Println("[MAIN] Service stopped gracefully")
}
