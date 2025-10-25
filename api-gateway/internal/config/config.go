package config

import (
	"fmt"
	"strings"
	"sync"

	"github.com/spf13/viper"
)

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

	// Load mode config
	vpr.SetConfigName(mode)
	vpr.SetConfigType("yaml")
	vpr.AddConfigPath("./config")
	if err := vpr.MergeInConfig(); err != nil {
		return nil, fmt.Errorf("failed to read mode config: %w", err)
	}

	// Load ratelimit config
	ratelimitVpr := viper.New()
	ratelimitVpr.SetConfigName("ratelimit")
	ratelimitVpr.SetConfigType("yaml")
	ratelimitVpr.AddConfigPath("./config")
	if err := ratelimitVpr.ReadInConfig(); err != nil {
		return nil, fmt.Errorf("failed to read ratelimit config: %w", err)
	}

	// Merge ratelimit into main config
	if err := vpr.MergeConfigMap(ratelimitVpr.AllSettings()); err != nil {
		return nil, fmt.Errorf("failed to merge ratelimit config: %w", err)
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
