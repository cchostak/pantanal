package main

import (
	"context"
	"errors"
	"log"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"example.invalid/pantanal/sample-app/internal/config"
	"example.invalid/pantanal/sample-app/internal/server"
)

var version = "dev"

func main() {
	configuration, err := config.Load()
	if err != nil {
		log.Fatalf("invalid configuration: %v", err)
	}
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: configuration.LogLevel}))
	slog.SetDefault(logger)
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	if err := run(ctx, configuration); err != nil {
		logger.Error("server stopped", "error", err)
		os.Exit(1)
	}
}

func run(ctx context.Context, configuration config.Config) error {
	handler := server.New(version)
	httpServer := &http.Server{
		Addr:              configuration.ListenAddress,
		Handler:           handler,
		ReadHeaderTimeout: configuration.ReadHeaderTimeout,
		ReadTimeout:       configuration.ReadTimeout,
		WriteTimeout:      configuration.WriteTimeout,
		IdleTimeout:       configuration.IdleTimeout,
	}
	listenConfig := &net.ListenConfig{}
	listener, err := listenConfig.Listen(ctx, "tcp", httpServer.Addr)
	if err != nil {
		return err
	}
	handler.SetReady(true)
	slog.Info("server starting", "version", version, "address", listener.Addr().String())

	serveErrors := make(chan error, 1)
	go func() {
		serveErrors <- httpServer.Serve(listener)
	}()

	select {
	case err := <-serveErrors:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	case <-ctx.Done():
		handler.SetReady(false)
		shutdownCtx, cancel := context.WithTimeout(context.Background(), configuration.ShutdownTimeout)
		defer cancel()
		return httpServer.Shutdown(shutdownCtx)
	}
}
