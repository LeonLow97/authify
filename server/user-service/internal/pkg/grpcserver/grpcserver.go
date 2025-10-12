package grpcserver

import (
	"fmt"
	"log"
	"net"

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
	// creates a new grpc server
	grpcServer := grpc.NewServer()

	// initialize health server for grpc
	healthService := health.NewServer()
	grpc_health_v1.RegisterHealthServer(grpcServer, healthService)
	healthService.SetServingStatus(app.Config.Server.Name, grpc_health_v1.HealthCheckResponse_SERVING) // to set the status of grpc server when performing health checks

	// gRPC reflection for service discovery by grpc clients
	// allows gRPC clients to discovery the services and methods exposed by a gRPC server at runtime
	// useful for service discovery, introspection tools (like grpcurl), and debugging
	reflection.Register(grpcServer)

	// register authentication and user grpc server
	authGRPCServer := inbound.NewAuthGRPCServer(app.Service)
	userGRPCServer := inbound.NewUserGRPCServer(app.Service)
	pb.RegisterAuthenticationServiceServer(grpcServer, authGRPCServer)
	pb.RegisterUserServiceServer(grpcServer, userGRPCServer)

	lis, err := net.Listen("tcp", fmt.Sprintf(":%d", app.Config.Server.Port))
	if err != nil {
		log.Fatalf("failed to start grpc server with error: %v\n", err)
	}
	log.Printf("Started authentication gRPC server at %v\n", lis.Addr())

	if err := grpcServer.Serve(lis); err != nil {
		log.Fatalf("failed to start authentication gRPC server with error: %v\n", err)
	}
}
