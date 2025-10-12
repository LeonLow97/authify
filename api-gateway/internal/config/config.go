package config

import (
	"fmt"
	"strings"
	"sync"

	"github.com/spf13/viper"
)

type Config struct {
	Mode        string            `mapstructure:"mode"`
	Server      ServerConfig      `mapstructure:"server"`
	RedisConfig RedisConfig       `mapstructure:"redis"`
	UserService UserServiceConfig `mapstructure:"user_service"`

	AuthJWTToken AuthJWTTokenConfig `mapstructure:"auth_jwt_token"`
	// HashicorpConsulConfig HashicorpConsulConfig `mapstructure:"hashicorp_consul"`
}

type ServerConfig struct {
	BaseUrl string `mapstructure:"base_url"`
	Port    int    `mapstructure:"port"`
}

type RedisConfig struct {
	Port          int    `mapstructure:"port"`
	Address       string `mapstructure:"address"`
	Password      string `mapstructure:"password"`
	DatabaseIndex int    `mapstructure:"database_index"`
}

type UserServiceConfig struct {
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

type HashicorpConsulConfig struct {
	Port    int    `mapstructure:"port"`
	Address string `mapstructure:"address"`
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

// LoadConfig loads config from disk/env — PURE, NO SIDE EFFECTS, fully testable.
func LoadConfig() (*Config, error) {
	vpr := viper.New()
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
		vpr.AddConfigPath("./config")
	} else {
		vpr.AddConfigPath("/app/config")
	}

	if err := vpr.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); ok {
			return nil, fmt.Errorf("no config file found for mode %q", mode)
		}
		return nil, fmt.Errorf("failed reading config: %w", err)
	}

	var c Config
	c.setDefaultValues(vpr)
	if err := vpr.Unmarshal(&c); err != nil {
		return nil, fmt.Errorf("failed unmarshaling config: %w", err)
	}
	c.Mode = mode
	return &c, nil
}

var (
	once sync.Once // singleton pattern
)

// GetConfig returns the global config instance (loaded once).
// Safe for concurrent use. Panics on load error (fail-fast).
func GetConfig() (*Config, error) {
	var err error
	var cfg *Config
	once.Do(func() {
		cfg, err = LoadConfig()
	})
	return cfg, err
}

func (c *Config) setDefaultValues(vpr *viper.Viper) {
	vpr.SetDefault("server.url", "localhost")
	vpr.SetDefault("server.port", 80)
}
