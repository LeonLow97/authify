package config

import (
	"fmt"
	"log"
	"strings"

	"github.com/spf13/viper"
)

type Config struct {
	Mode   string `mapstructure:"mode"`
	Server struct {
		Name string `mapstructure:"name"`
		Port int    `mapstructure:"port"`
	} `mapstructure:"server"`
	JWTConfig             JWTConfig             `mapstructure:"jwt"`
	PostgresConfig        PostgresConfig        `mapstructure:"postgres"`
	HashicorpConsulConfig HashicorpConsulConfig `mapstructure:"hashicorp_consul"`
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

type HashicorpConsulConfig struct {
	ID      string `mapstructure:"id"`
	Name    string `mapstructure:"name"`
	Port    int    `mapstructure:"port"`
	Address string `mapstructure:"address"`
}

// LoadConfig reads configuration based on the current mode.
// It loads environment variables, reads the config file, and Unmarshal it into a Config struct
func LoadConfig() (*Config, error) {
	// Create a new Viper instance to manage configuration settings
	vpr := viper.New()

	// Replace '.' with '_' in environment variable names to match common conventions
	// E.g., "DATABASE.HOST" becomes "DATABASE_HOST"
	vpr.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))

	// Automatically bind environment variables to Viper keys
	// This allows configuration values to be overridden by environment variables
	vpr.AutomaticEnv()

	// Retrieve the "MODE" environment variable to determine the configuration mode
	// If not set, default to Development mode
	mode := vpr.GetString("MODE")
	if mode == "" {
		mode = ModeDevelopment
	}

	// Set the configuration file name based on the mode (e.g., "development.yaml")
	vpr.SetConfigName(mode)

	// Add the directory "/app/config" as a location to search for the configuration file
	vpr.AddConfigPath("/app/config")

	if err := vpr.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); ok {
			return nil, fmt.Errorf("config file not found with error: %v", err)
		}
		log.Println("Failed to read config file using Viper with error:", err)
		return nil, err
	}

	// Unmarshal the configuration file into the Config struct
	var config Config
	if err := vpr.Unmarshal(&config); err != nil {
		return nil, fmt.Errorf("failed to unmarshal config with error: %v", err)
	}

	return &config, nil
}
