// Package server implements the sample HTTP service and its Prometheus metrics.
package server

import (
	"fmt"
	"net/http"
	"strconv"
	"sync"
	"sync/atomic"
)

// Handler exposes application, health, and metrics endpoints.
type Handler struct {
	version string
	mu      sync.Mutex
	counts  map[string]uint64
	mux     *http.ServeMux
	ready   atomic.Bool
}

// New returns an isolated application handler.
func New(version string) *Handler {
	handler := &Handler{
		version: version,
		counts:  make(map[string]uint64),
	}
	mux := http.NewServeMux()
	mux.HandleFunc("/", handler.root)
	mux.HandleFunc("/healthz", handler.health)
	mux.HandleFunc("/readyz", handler.readiness)
	mux.HandleFunc("/metrics", handler.metrics)
	handler.mux = mux
	return handler
}

// SetReady changes whether the readiness endpoint accepts traffic.
func (h *Handler) SetReady(ready bool) {
	h.ready.Store(ready)
}

// ServeHTTP adds response guardrails before routing the request.
func (h *Handler) ServeHTTP(writer http.ResponseWriter, request *http.Request) {
	writer.Header().Set("Cache-Control", "no-store")
	writer.Header().Set("X-Content-Type-Options", "nosniff")
	writer.Header().Set("X-Frame-Options", "DENY")
	if request.Method != http.MethodGet {
		writer.Header().Set("Allow", http.MethodGet)
		h.record(http.StatusMethodNotAllowed)
		http.Error(writer, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	h.mux.ServeHTTP(writer, request)
}

func (h *Handler) root(writer http.ResponseWriter, request *http.Request) {
	if request.URL.Path != "/" {
		h.record(http.StatusNotFound)
		http.NotFound(writer, request)
		return
	}
	h.record(http.StatusOK)
	writer.Header().Set("Content-Type", "application/json")
	_, _ = fmt.Fprintf(writer, `{"service":"sample-app","version":%s}`+"\n", strconv.Quote(h.version))
}

func (h *Handler) health(writer http.ResponseWriter, _ *http.Request) {
	h.record(http.StatusOK)
	writer.Header().Set("Content-Type", "text/plain; charset=utf-8")
	writer.WriteHeader(http.StatusOK)
	_, _ = fmt.Fprintln(writer, "ok")
}

func (h *Handler) readiness(writer http.ResponseWriter, _ *http.Request) {
	if !h.ready.Load() {
		h.record(http.StatusServiceUnavailable)
		http.Error(writer, "not ready", http.StatusServiceUnavailable)
		return
	}
	h.record(http.StatusOK)
	writer.Header().Set("Content-Type", "text/plain; charset=utf-8")
	writer.WriteHeader(http.StatusOK)
	_, _ = fmt.Fprintln(writer, "ready")
}

func (h *Handler) metrics(writer http.ResponseWriter, _ *http.Request) {
	h.record(http.StatusOK)
	h.mu.Lock()
	defer h.mu.Unlock()

	writer.Header().Set("Content-Type", "text/plain; version=0.0.4")
	_, _ = fmt.Fprintln(writer, "# HELP http_requests_total Total HTTP requests by response code.")
	_, _ = fmt.Fprintln(writer, "# TYPE http_requests_total counter")
	for code, count := range h.counts {
		_, _ = fmt.Fprintf(writer, "http_requests_total{code=%q} %d\n", code, count)
	}
}

func (h *Handler) record(status int) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.counts[strconv.Itoa(status)]++
}
