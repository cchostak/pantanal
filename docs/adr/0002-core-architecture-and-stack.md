# 0002: Core architecture and stack

- Status: Accepted
- Date: 2026-08-29
- Deciders: Pantanal maintainers

## Context

Pantanal needs a reproducible local reference implementation of a secure
software-delivery control plane. Build and deployment authority must remain
separate, and promotion must be based on immutable, verified artifacts.

## Decision

- Nix flakes pin the developer toolchain and build a deterministic, non-root
  OCI image for the Go HTTP service.
- Gitea accepts source changes and sends an internal HTTP webhook to a Tekton
  EventListener. CEL binds accepted events to the repository, `main`, a valid
  commit SHA, and a loop-prevention rule.
- Tekton builds and pushes to Harbor, blocks high and critical findings with
  Trivy, signs the digest with Cosign, verifies it, then commits only the digest.
- Argo CD has read-only source credentials and reconciles through a restricted
  AppProject. Argo Rollouts performs metric-gated canary promotion.
- Kyverno and Pod Security Admission reject unsafe or mutable workloads.
- Prometheus supplies the rollout success-rate signal.

## Security boundaries

Build automation has no deployment permission. Deployment automation has no
registry push or signing key. Runtime workloads receive no Kubernetes token,
run as a non-root numeric identity, and use a read-only filesystem. Local HTTP
and an insecure local registry are accepted only inside the disposable kind
network; this scaffold is not an internet-facing production topology.

## Consequences

The platform demonstrates hermetic builds and policy-gated GitOps without a
cloud account. Bootstrap is heavier than a single application container, and
production adoption requires managed persistence, TLS, external identity,
backups, and high availability.
