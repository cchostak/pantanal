package main

import (
	"context"
	"testing"
	"time"

	"example.invalid/pantanal/sample-app/internal/config"
)

func testConfiguration(address string) config.Config {
	return config.Config{
		ListenAddress:     address,
		ReadHeaderTimeout: time.Second,
		ReadTimeout:       time.Second,
		WriteTimeout:      time.Second,
		IdleTimeout:       time.Second,
		ShutdownTimeout:   time.Second,
	}
}

func TestRunRejectsUnavailableAddress(t *testing.T) {
	if err := run(context.Background(), testConfiguration("invalid")); err == nil {
		t.Fatal("run() error = nil, want listen error")
	}
}

func TestRunShutsDownWhenContextEnds(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	time.AfterFunc(10*time.Millisecond, cancel)
	if err := run(ctx, testConfiguration("127.0.0.1:0")); err != nil {
		t.Fatalf("run() error = %v", err)
	}
}
