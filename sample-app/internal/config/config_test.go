package config_test

import (
	"log/slog"
	"strings"
	"testing"
	"time"

	"example.invalid/pantanal/sample-app/internal/config"
)

func clearEnvironment(t *testing.T) {
	t.Helper()
	for _, name := range []string{"LISTEN_ADDRESS", "READ_HEADER_TIMEOUT", "READ_TIMEOUT", "WRITE_TIMEOUT", "IDLE_TIMEOUT", "SHUTDOWN_TIMEOUT", "LOG_LEVEL"} {
		t.Setenv(name, "")
	}
}

func TestLoadDefaults(t *testing.T) {
	clearEnvironment(t)
	got, err := config.Load()
	if err != nil {
		t.Fatal(err)
	}
	if got.ListenAddress != ":8080" || got.LogLevel != slog.LevelInfo {
		t.Fatalf("defaults = %#v", got)
	}
	if got.ReadHeaderTimeout != 5*time.Second || got.ShutdownTimeout != 10*time.Second {
		t.Fatalf("timeout defaults = %#v", got)
	}
}

func TestLoadOverrides(t *testing.T) {
	clearEnvironment(t)
	t.Setenv("LISTEN_ADDRESS", "127.0.0.1:9090")
	t.Setenv("READ_HEADER_TIMEOUT", "1s")
	t.Setenv("READ_TIMEOUT", "2s")
	t.Setenv("WRITE_TIMEOUT", "3s")
	t.Setenv("IDLE_TIMEOUT", "4s")
	t.Setenv("SHUTDOWN_TIMEOUT", "5s")
	t.Setenv("LOG_LEVEL", "debug")
	got, err := config.Load()
	if err != nil {
		t.Fatal(err)
	}
	if got.ListenAddress != "127.0.0.1:9090" || got.ReadTimeout != 2*time.Second || got.LogLevel != slog.LevelDebug {
		t.Fatalf("overrides = %#v", got)
	}
}

func TestLoadRejectsInvalidAddress(t *testing.T) {
	clearEnvironment(t)
	t.Setenv("LISTEN_ADDRESS", "8080")
	_, err := config.Load()
	if err == nil || !strings.Contains(err.Error(), "LISTEN_ADDRESS") {
		t.Fatalf("error = %v, want LISTEN_ADDRESS error", err)
	}
}

func TestLoadRejectsInvalidDuration(t *testing.T) {
	clearEnvironment(t)
	t.Setenv("READ_TIMEOUT", "soon")
	_, err := config.Load()
	if err == nil || !strings.Contains(err.Error(), "READ_TIMEOUT") {
		t.Fatalf("error = %v, want READ_TIMEOUT error", err)
	}
}

func TestLoadRejectsNonPositiveDuration(t *testing.T) {
	clearEnvironment(t)
	t.Setenv("SHUTDOWN_TIMEOUT", "0s")
	_, err := config.Load()
	if err == nil || !strings.Contains(err.Error(), "greater than zero") {
		t.Fatalf("error = %v, want positive duration error", err)
	}
}

func TestLoadRejectsInvalidLogLevel(t *testing.T) {
	clearEnvironment(t)
	t.Setenv("LOG_LEVEL", "verbose")
	_, err := config.Load()
	if err == nil || !strings.Contains(err.Error(), "LOG_LEVEL") {
		t.Fatalf("error = %v, want LOG_LEVEL error", err)
	}
}
