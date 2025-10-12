package main

import (
	"fmt"
	"log"

	"github.com/LeonLow97/internal/adapters/inbound/web"
	grpcclient "github.com/LeonLow97/internal/adapters/outbound/grpc"
	"github.com/LeonLow97/internal/config"
	"github.com/LeonLow97/internal/pkg/cache"
)

type application struct {
	cfg              *config.Config
	GRPCClient       grpcclient.GRPCClient
	AppCache         cache.Cache
	AuthHandler      *web.AuthHandler
	UserHandler      *web.UserHandler
	InventoryHandler *web.InventoryHandler
	OrderHandler     *web.OrderHandler
}

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

	// grpcClient := grpcclient.NewGRPCClient(*cfg, nil)
	// defer grpcClient.AuthenticationClient().Close()
	// defer grpcClient.InventoryClient().Close()
	// defer grpcClient.OrderClient().Close()

	// instantiating auth microservice
	// authRepo := grpcclient.NewAuthRepo(grpcClient.AuthenticationClient())
	// authService := auth.NewAuthService(authRepo)
	// authHandler := web.NewAuthHandler(*cfg, authService)

	// // instantiating user microservice
	// userRepo := grpcclient.NewUserRepo(grpcClient.AuthenticationClient())
	// userService := user.NewUserService(userRepo)
	// userHandler := web.NewUserHandler(userService)

	// // instantiating inventory microservice
	// inventoryRepo := grpcclient.NewInventoryRepo(grpcClient.InventoryClient())
	// inventoryService := inventory.NewInventoryService(inventoryRepo)
	// inventoryHandler := web.NewInventoryHandler(inventoryService)

	// // instantiating order microservice
	// orderRepo := grpcclient.NewOrderRepo(grpcClient.OrderClient())
	// orderService := order.NewOrderService(orderRepo)
	// orderHandler := web.NewOrderHandler(orderService)

	app := application{
		cfg: cfg,
		// AppCache:    appCache,
		// GRPCClient:  grpcClient,
		// AuthHandler: authHandler,
		// UserHandler: userHandler,
		// InventoryHandler: inventoryHandler,
		// OrderHandler:     orderHandler,
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
