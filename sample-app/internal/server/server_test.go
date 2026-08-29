package server_test

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"example.invalid/pantanal/sample-app/internal/server"
)

func TestHandler(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name        string
		path        string
		status      int
		contentType string
		body        string
	}{
		{name: "root", path: "/", status: http.StatusOK, contentType: "application/json", body: `"version":"test-v1"`},
		{name: "health", path: "/healthz", status: http.StatusOK, contentType: "text/plain", body: "ok"},
		{name: "not ready", path: "/readyz", status: http.StatusServiceUnavailable, contentType: "text/plain", body: "not ready"},
		{name: "missing", path: "/missing", status: http.StatusNotFound, contentType: "text/plain", body: "404 page not found"},
		{name: "metrics", path: "/metrics", status: http.StatusOK, contentType: "text/plain", body: "http_requests_total"},
	}

	for _, test := range tests {
		test := test
		t.Run(test.name, func(t *testing.T) {
			t.Parallel()
			request := httptest.NewRequestWithContext(context.Background(), http.MethodGet, test.path, nil)
			response := httptest.NewRecorder()
			server.New("test-v1").ServeHTTP(response, request)

			if response.Code != test.status {
				t.Fatalf("status = %d, want %d", response.Code, test.status)
			}
			if got := response.Header().Get("Content-Type"); !strings.Contains(got, test.contentType) {
				t.Errorf("Content-Type = %q, want substring %q", got, test.contentType)
			}
			if !strings.Contains(response.Body.String(), test.body) {
				t.Errorf("body = %q, want substring %q", response.Body.String(), test.body)
			}
		})
	}
}

func TestReadinessTransition(t *testing.T) {
	t.Parallel()
	handler := server.New("test-v1")
	handler.SetReady(true)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, httptest.NewRequestWithContext(context.Background(), http.MethodGet, "/readyz", nil))
	if response.Code != http.StatusOK || !strings.Contains(response.Body.String(), "ready") {
		t.Fatalf("response = %d %q, want ready", response.Code, response.Body.String())
	}
}

func TestMethodGuard(t *testing.T) {
	t.Parallel()
	response := httptest.NewRecorder()
	server.New("test-v1").ServeHTTP(response, httptest.NewRequestWithContext(context.Background(), http.MethodPost, "/", nil))
	if response.Code != http.StatusMethodNotAllowed {
		t.Fatalf("status = %d, want 405", response.Code)
	}
	if response.Header().Get("Allow") != http.MethodGet {
		t.Errorf("Allow = %q, want GET", response.Header().Get("Allow"))
	}
}

func TestSecurityHeaders(t *testing.T) {
	t.Parallel()
	response := httptest.NewRecorder()
	server.New("test-v1").ServeHTTP(response, httptest.NewRequestWithContext(context.Background(), http.MethodGet, "/healthz", nil))
	for name, want := range map[string]string{
		"Cache-Control":          "no-store",
		"X-Content-Type-Options": "nosniff",
		"X-Frame-Options":        "DENY",
	} {
		if got := response.Header().Get(name); got != want {
			t.Errorf("%s = %q, want %q", name, got, want)
		}
	}
}

func TestMetricsCountStatusCodes(t *testing.T) {
	t.Parallel()
	handler := server.New("test-v1")
	handler.SetReady(true)
	for _, path := range []string{"/", "/healthz", "/readyz", "/missing", "/metrics"} {
		handler.ServeHTTP(httptest.NewRecorder(), httptest.NewRequestWithContext(context.Background(), http.MethodGet, path, nil))
	}

	response := httptest.NewRecorder()
	handler.ServeHTTP(response, httptest.NewRequestWithContext(context.Background(), http.MethodGet, "/metrics", nil))
	body, err := io.ReadAll(response.Result().Body)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(body), `http_requests_total{code="200"} 5`) {
		t.Errorf("metrics = %q, want successful request count", body)
	}
	if !strings.Contains(string(body), `http_requests_total{code="404"} 1`) {
		t.Errorf("metrics = %q, want not-found request count", body)
	}
}
