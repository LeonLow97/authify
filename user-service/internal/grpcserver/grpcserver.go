package grpcserver

import (
	"fmt"
	"log"
	"net"
	"os"
	"os/signal"
	"syscall"

	"github.com/LeonLow97/internal/adapters/inbound"
	"github.com/LeonLow97/internal/core/services"
	"github.com/LeonLow97/internal/pkg/config"
	pb "github.com/LeonLow97/proto"
	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	"google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"
)

type Application struct {
	Config  config.Config
	Service services.Service
}

func (app *Application) InitiateGRPCServer() {
	server := grpc.NewServer(
		grpc.MaxConcurrentStreams(1000),
	)

	app.registerHealth(server)
	app.registerReflection(server)
	app.registerUserService(server)

	addr := fmt.Sprintf(":%d", app.Config.Server.Port)
	lis, err := net.Listen("tcp", addr)
	if err != nil {
		log.Fatalf("[gRPC] failed to listen on %s: %v", addr, err)
	}

	log.Printf("[gRPC] Server listening on %s", addr)

	// Graceful shutdown
	go func() {
		sigCh := make(chan os.Signal, 1)
		signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
		<-sigCh

		log.Println("[gRPC] Shutdown signal received, stopping server...")
		server.GracefulStop()
	}()

	if err := server.Serve(lis); err != nil {
		log.Fatalf("[gRPC] Server stopped with error: %v", err)
	}
}

func (app *Application) registerHealth(server *grpc.Server) {
	healthService := health.NewServer()
	grpc_health_v1.RegisterHealthServer(server, healthService)
	healthService.SetServingStatus(app.Config.Server.Name, grpc_health_v1.HealthCheckResponse_SERVING)
}

func (app *Application) registerReflection(server *grpc.Server) {
	reflection.Register(server)
	log.Println("[gRPC] Reflection enabled")
}

func (app *Application) registerUserService(server *grpc.Server) {
	userServer := inbound.NewInbound(app.Service)
	pb.RegisterUserServiceServer(server, userServer)
}
