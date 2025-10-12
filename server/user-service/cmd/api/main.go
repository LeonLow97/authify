package main

import (
	"log"

	_ "github.com/golang-migrate/migrate/v4/source/file"

	"github.com/LeonLow97/internal/adapters/outbound"
	"github.com/LeonLow97/internal/core/services"
	"github.com/LeonLow97/internal/pkg/config"
	"github.com/LeonLow97/internal/pkg/db"
	"github.com/LeonLow97/internal/pkg/grpcserver"
)

func main() {
	cfg, err := config.LoadConfig()
	if err != nil {
		log.Fatalln("Failed to load config with error:", err)
	}

	conn, err := db.ConnectToDB(*cfg)
	if err != nil {
		log.Fatalln("Failed to connect to database with error:", err)
	}

	// initialize grpc authentication and user services
	repo := outbound.NewRepository(conn)
	service := services.NewService(repo, *cfg)

	app := grpcserver.Application{
		Config:  *cfg,
		Service: service,
	}

	go app.InitiateGRPCServer()

	// // register authentication microservice with service discovery consul
	// serviceDiscovery := consul.NewConsul(*cfg)
	// if err := serviceDiscovery.RegisterService(); err != nil {
	// 	log.Fatalf("failed to register authentication microservice with error: %v\n", err)
	// }

	select {}
}
