package main

import (
	"fmt"
	"log"

	"github.com/LeonLow97/internal/adapters/inbound/web"
	grpcclient "github.com/LeonLow97/internal/adapters/outbound/grpc"
	"github.com/LeonLow97/internal/config"
	"github.com/LeonLow97/internal/core/services/user"
)

func main() {
	// Load Config
	cfg := config.GetConfig()

	// Load application cache
	// appCache := cache.NewRedisClient(*cfg)

	// // create a consul client
	// hashicorpConsul := consul.NewConsul(*cfg)
	// hashicorpClient, err := hashicorpConsul.NewConsul(*cfg)
	// if err != nil {
	// 	log.Fatalf("failed to create hashicorp consul client with error: %v\n", err)
	// }
	// log.Println("successfully created hashicorp client")

	// ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	// defer cancel()

	// if err := hashicorpClient.RefreshServices(ctx); err != nil {
	// 	log.Fatalln("failed to refresh services", err)
	// }

	grpcClient := grpcclient.NewGRPCClient(*cfg, nil)
	defer grpcClient.AuthenticationClient().Close()

	// instantiating user microservice
	userRepo := grpcclient.NewUserRepo(grpcClient.AuthenticationClient())
	userService := user.NewUserService(userRepo)
	userHandler := web.NewUserHandler(*cfg, userService)

	app := application{
		cfg: cfg,
		// AppCache:    appCache,
		// GRPCClient:  grpcClient,
		UserHandler: userHandler,
	}
	router := app.routes()

	serverAddr := fmt.Sprintf("%s:%d", cfg.Server.BaseUrl, cfg.Server.Port)
	log.Printf("Starting API Gateway | Server Address: '%s' \n", serverAddr)
	if err := router.Run(serverAddr); err != nil {
		log.Fatalf("failed to start api gateway server with error: %v\n", err)
	}

	// Deprecated Code
	// apiGatewayPort := fmt.Sprintf(":%d", cfg.Server.Port)
	// apiGatewayPort := "0.0.0.0:8080"
}
