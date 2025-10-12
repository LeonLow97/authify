package consul

import (
	"fmt"
	"log"

	"github.com/LeonLow97/internal/pkg/config"
	"github.com/hashicorp/consul/api"
)

type Consul struct {
	cfg config.Config
}

// NewConsul initializes a new Consul instance
func NewConsul(cfg config.Config) *Consul {
	return &Consul{
		cfg: cfg,
	}
}

// RegisterService registers the service with HashiCorp Consul
func (c *Consul) RegisterService() error {
	// Create a new Consul client with default configuration
	client, err := api.NewClient(&api.Config{
		Address: fmt.Sprintf("%s:%d", c.cfg.HashicorpConsulConfig.Address, c.cfg.HashicorpConsulConfig.Port),
	})
	if err != nil {
		log.Printf("failed to create consul client with error: %v\n", err)
		return err
	}

	// Define the health check configuration for the service
	serviceCheck := &api.AgentServiceCheck{
		// Specify the gRPC endpoint for health checks using the service's name and port
		GRPC: fmt.Sprintf("%s:%d",
			c.cfg.Server.Name,
			c.cfg.Server.Port,
		),
		Interval: "10s", // How often to check the service's health
		Timeout:  "5s",  // How long to wait for a health check response
	}

	service := &api.AgentServiceRegistration{
		ID:      c.cfg.Server.Name,
		Name:    c.cfg.Server.Name,
		Port:    c.cfg.Server.Port,
		Address: c.cfg.Server.Name,
		Tags:    []string{"auth"},
		Check:   serviceCheck,
	}

	// register the service with consul
	if err := client.Agent().ServiceRegister(service); err != nil {
		log.Printf("failed to register authentication service with consul with error: %v\n", err)
		return err
	}

	log.Println("successfully registered authentication microservice with hashicorp consul service discovery")
	return nil
}
