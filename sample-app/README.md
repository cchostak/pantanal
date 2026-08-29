# Sample application

The sample service uses only the Go standard library. Nix runs its tests,
builds a static binary, creates a non-root deterministic OCI filesystem, and
emits a Docker archive without a Dockerfile.

```bash
go test -race ./...
nix flake check
nix build .#container
skopeo inspect docker-archive:result
```

Run it directly with `go run .`, then query `/healthz`, `/readyz`, `/`, and
`/metrics` on port 8080. Server settings are documented in the root README.
