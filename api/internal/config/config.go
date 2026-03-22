// Package config handles configuration loading for the Hyper-NixOS API
package config

import (
	"github.com/spf13/viper"
)

// Config holds the application configuration
type Config struct {
	API      APIConfig      `mapstructure:"api"`
	Database DatabaseConfig `mapstructure:"database"`
	Auth     AuthConfig     `mapstructure:"auth"`
	Events   EventsConfig   `mapstructure:"events"`
}

// APIConfig holds API server configuration
type APIConfig struct {
	Host      string     `mapstructure:"host"`
	Port      int        `mapstructure:"port"`
	Debug     bool       `mapstructure:"debug"`
	TLS       TLSConfig  `mapstructure:"tls"`
	CORS      CORSConfig `mapstructure:"cors"`
	RateLimit int        `mapstructure:"rate_limit"`
}

// TLSConfig holds TLS configuration
type TLSConfig struct {
	Enabled  bool   `mapstructure:"enabled"`
	CertFile string `mapstructure:"cert_file"`
	KeyFile  string `mapstructure:"key_file"`
}

// CORSConfig holds CORS configuration
type CORSConfig struct {
	AllowedOrigins []string `mapstructure:"allowed_origins"`
	AllowedMethods []string `mapstructure:"allowed_methods"`
	AllowedHeaders []string `mapstructure:"allowed_headers"`
}

// DatabaseConfig holds database configuration
type DatabaseConfig struct {
	Driver string `mapstructure:"driver"`
	DSN    string `mapstructure:"dsn"`
}

// AuthConfig holds authentication configuration
type AuthConfig struct {
	JWTSecret     string `mapstructure:"jwt_secret"`
	TokenExpiry   int    `mapstructure:"token_expiry"`
	RefreshExpiry int    `mapstructure:"refresh_expiry"`
}

// EventsConfig holds event system configuration
type EventsConfig struct {
	NATSUrl string `mapstructure:"nats_url"`
	Subject string `mapstructure:"subject"`
}

// Load reads configuration from file and environment
func Load() (*Config, error) {
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath("/etc/hypervisor")
	viper.AddConfigPath(".")

	// Set defaults
	viper.SetDefault("api.host", "0.0.0.0")
	viper.SetDefault("api.port", 8080)
	viper.SetDefault("api.debug", false)
	viper.SetDefault("api.rate_limit", 100)
	viper.SetDefault("database.driver", "sqlite")
	viper.SetDefault("database.dsn", "/var/lib/hypervisor/api.db")
	viper.SetDefault("auth.token_expiry", 3600)
	viper.SetDefault("auth.refresh_expiry", 86400)
	viper.SetDefault("events.nats_url", "nats://localhost:4222")
	viper.SetDefault("events.subject", "hypervisor.events")

	// Read config file (optional)
	_ = viper.ReadInConfig()

	// Allow environment variable overrides
	viper.AutomaticEnv()

	var cfg Config
	if err := viper.Unmarshal(&cfg); err != nil {
		return nil, err
	}

	return &cfg, nil
}
