package config

import (
	"fmt"
	"strings"
	"sync"

	"github.com/spf13/viper"
)

type Config struct {
	Mode   string `mapstructure:"mode"`
	Server struct {
		Name string `mapstructure:"name"`
		Port int    `mapstructure:"port"`
	} `mapstructure:"server"`
	JWTConfig      JWTConfig      `mapstructure:"jwt"`
	PostgresConfig PostgresConfig `mapstructure:"postgres"`
	RedisConfig    RedisConfig    `mapstructure:"redis"`
}

type JWTConfig struct {
	SecretKey string `mapstructure:"secret_key"`
	Expiry    int    `mapstructure:"expiry"`
}

type PostgresConfig struct {
	User     string `mapstructure:"user"`
	Password string `mapstructure:"password"`
	Host     string `mapstructure:"host"`
	Port     int    `mapstructure:"port"`
	DB       string `mapstructure:"db"`
}

type RedisConfig struct {
	Address       string `mapstructure:"address"`
	Port          int    `mapstructure:"port"`
	Password      string `mapstructure:"password"`
	DatabaseIndex int    `mapstructure:"database_index"`
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
	vpr.SetDefault("server.port", 50051)
}
