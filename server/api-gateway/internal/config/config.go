package config

import (
	"fmt"
	"strings"

	"github.com/spf13/viper"
)

type Config struct {
	Mode                  string                 `mapstructure:"mode"`
	Server                ServerConfig           `mapstructure:"server"`
	AuthJWTToken          AuthJWTTokenConfig     `mapstructure:"auth_jwt_token"`
	AuthService           AuthServiceConfig      `mapstructure:"auth_service"`
	InventoryService      InventoryServiceConfig `mapstructure:"inventory_service"`
	OrderService          OrderServiceConfig     `mapstructure:"order_service"`
	HashicorpConsulConfig HashicorpConsulConfig  `mapstructure:"hashicorp_consul"`
	RedisServer           RedisServerConfig      `mapstructure:"redis_server"`
	RateLimiting          RateLimitingConfig     `mapstructure:"rate_limiting"`
	AdminWhitelistedIPs   []string               `mapstructure:"admin_whitelisted_ips"`
}

type ServerConfig struct {
	BaseUrl string `mapstructure:"base_url"`
	Port    int    `mapstructure:"port"`
}

type AuthJWTTokenConfig struct {
	Name     string `mapstructure:"name"`
	Secret   string `mapstructure:"secret"`
	MaxAge   int    `mapstructure:"max_age"`
	Domain   string `mapstructure:"domain"`
	Secure   bool   `mapstructure:"secure"`
	HTTPOnly bool   `mapstructure:"http_only"`
	Path     string `mapstructure:"path"`
}

type AuthServiceConfig struct {
	Name string `mapstructure:"name"`
}

type InventoryServiceConfig struct {
	Name string `mapstructure:"name"`
}

type OrderServiceConfig struct {
	Name string `mapstructure:"name"`
}

type HashicorpConsulConfig struct {
	Port    int    `mapstructure:"port"`
	Address string `mapstructure:"address"`
}

type RedisServerConfig struct {
	Port          int    `mapstructure:"port"`
	Address       string `mapstructure:"address"`
	Password      string `mapstructure:"password"`
	DatabaseIndex int    `mapstructure:"database_index"`
}

type RateLimitingConfig struct {
	BucketLockExpiration int `mapstructure:"bucket_lock_expiration"`
	DistributedLocks     struct {
		Write  string `mapstructure:"write"`
		Read   string `mapstructure:"read"`
		Global string `mapstructure:"global"`
	} `mapstructure:"distributed_locks"`
}

const (
	ModeDevelopment = "development"
	ModeDocker      = "docker"
	ModeProduction  = "production"
)

var modes = map[string]struct{}{
	ModeDevelopment: {},
	ModeDocker:      {},
	ModeProduction:  {},
}

// LoadConfig reads configuration based on the current mode.
func LoadConfig() (*Config, error) {
	vpr := viper.New()

	// allow env vars like SERVER.PORT or SERVER_PORT to override
	vpr.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))
	vpr.AutomaticEnv()

	mode := vpr.GetString("MODE")
	if mode == "" {
		mode = ModeDevelopment
	}

	if _, ok := modes[mode]; !ok {
		return nil, fmt.Errorf("unknown MODE %q", mode)
	}

	vpr.SetConfigName(mode)

	if mode == ModeDevelopment {
		// development mode stores config in ./config
		vpr.AddConfigPath("./config")
	} else {
		vpr.AddConfigPath("/app/config")
	}

	if err := vpr.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); ok {
			return nil, fmt.Errorf("no config file found for mode %q: %v", mode, err)
		}
		return nil, fmt.Errorf("failed reading config file: %w", err)
	}

	var cfg Config
	cfg.setDefaultValues(vpr)
	if err := vpr.Unmarshal(&cfg); err != nil {
		return nil, fmt.Errorf("failed unmarshaling config file: %w", err)
	}

	cfg.Mode = mode
	return &cfg, nil
}

func (c *Config) setDefaultValues(vpr *viper.Viper) {
	vpr.SetDefault("server.url", "localhost")
	vpr.SetDefault("server.port", 80)
}
