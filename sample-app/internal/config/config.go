// Package config loads and validates process configuration from the environment.
package config

import (
	"fmt"
	"log/slog"
	"net"
	"os"
	"time"
)

const (
	defaultListenAddress   = ":8080"
	defaultReadHeader      = 5 * time.Second
	defaultReadTimeout     = 15 * time.Second
	defaultWriteTimeout    = 30 * time.Second
	defaultIdleTimeout     = 60 * time.Second
	defaultShutdownTimeout = 10 * time.Second
)

// Config contains validated HTTP server and logging configuration.
type Config struct {
	ListenAddress     string
	ReadHeaderTimeout time.Duration
	ReadTimeout       time.Duration
	WriteTimeout      time.Duration
	IdleTimeout       time.Duration
	ShutdownTimeout   time.Duration
	LogLevel          slog.Level
}

// Load reads configuration from environment variables and applies safe defaults.
func Load() (Config, error) {
	configuration := Config{
		ListenAddress:     valueOrDefault("LISTEN_ADDRESS", defaultListenAddress),
		ReadHeaderTimeout: defaultReadHeader,
		ReadTimeout:       defaultReadTimeout,
		WriteTimeout:      defaultWriteTimeout,
		IdleTimeout:       defaultIdleTimeout,
		ShutdownTimeout:   defaultShutdownTimeout,
		LogLevel:          slog.LevelInfo,
	}
	durations := []struct {
		name   string
		target *time.Duration
	}{
		{name: "READ_HEADER_TIMEOUT", target: &configuration.ReadHeaderTimeout},
		{name: "READ_TIMEOUT", target: &configuration.ReadTimeout},
		{name: "WRITE_TIMEOUT", target: &configuration.WriteTimeout},
		{name: "IDLE_TIMEOUT", target: &configuration.IdleTimeout},
		{name: "SHUTDOWN_TIMEOUT", target: &configuration.ShutdownTimeout},
	}
	for _, setting := range durations {
		if err := parsePositiveDuration(setting.name, setting.target); err != nil {
			return Config{}, err
		}
	}
	if _, _, err := net.SplitHostPort(configuration.ListenAddress); err != nil {
		return Config{}, fmt.Errorf("LISTEN_ADDRESS must be host:port: %w", err)
	}
	if value := os.Getenv("LOG_LEVEL"); value != "" {
		if err := configuration.LogLevel.UnmarshalText([]byte(value)); err != nil {
			return Config{}, fmt.Errorf("LOG_LEVEL: %w", err)
		}
	}
	return configuration, nil
}

func parsePositiveDuration(name string, target *time.Duration) error {
	value := os.Getenv(name)
	if value == "" {
		return nil
	}
	duration, err := time.ParseDuration(value)
	if err != nil {
		return fmt.Errorf("%s: %w", name, err)
	}
	if duration <= 0 {
		return fmt.Errorf("%s must be greater than zero", name)
	}
	*target = duration
	return nil
}

func valueOrDefault(name, fallback string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}
	return fallback
}
