package client

import (
	"fmt"

	"github.com/LeonLow97/internal/config"
	pb "github.com/LeonLow97/proto"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

type GrpcClient interface {
	UserService() pb.UserServiceClient
	Close() error
}

type client struct {
	conn       *grpc.ClientConn
	userClient pb.UserServiceClient
}

// NewGrpcClient connects with the Grpc servers
func NewGrpcClient(cfg config.Config) (GrpcClient, error) {
	opts := []grpc.DialOption{
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithDefaultCallOptions(
			grpc.MaxCallRecvMsgSize(10 << 20), // 10MB
		),
	}

	serverAddr := fmt.Sprintf("%s:%d", cfg.UserService.BaseUrl, cfg.UserService.Port)
	conn, err := grpc.NewClient(serverAddr, opts...)
	if err != nil {
		return nil, fmt.Errorf("dial auth service %q: %w", serverAddr, err)
	}

	return &client{
		conn:       conn,
		userClient: pb.NewUserServiceClient(conn),
	}, nil
}

func (c *client) UserService() pb.UserServiceClient {
	return c.userClient
}

func (c *client) Close() error {
	if c.conn == nil {
		return nil
	}
	return c.conn.Close()
}
