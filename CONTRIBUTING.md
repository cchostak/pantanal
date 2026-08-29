# Contributing

## Setup

Install Nix with flakes enabled and Docker, then run:

```bash
make doctor
nix develop ./platform-infra
pre-commit install --install-hooks --hook-type pre-commit --hook-type commit-msg
make check
make test
```

Use `make bootstrap` only when a complete local control plane is needed. It
creates credentials under the ignored `platform-infra/secrets/` directory.

## Workflow

- Branch from `main` using `feat/`, `fix/`, `docs/`, `chore/`, or `security/`.
- Keep changes focused and update tests and documentation with behavior.
- Use Conventional Commits, such as `feat(pipeline): verify image signatures`.
- Rebase before review; do not force-push a branch another contributor owns.
- Never commit credentials, generated secret material, or scan reports.

## Pull requests

A pull request must explain the motivation, security and operational impact,
verification performed, and rollback approach. CI, security scanning, unit
tests, policy tests, and integration tests must pass. Changes to workflows,
RBAC, policy, signing, credentials, or deployment manifests require CODEOWNER
review.

## Local verification

```bash
make fmt
make check
make test
make scan
make test-smoke
```

The smoke test preserves a pre-existing Pantanal cluster. A cluster created by
the test is deleted automatically; set `PANTANAL_KEEP_SMOKE_CLUSTER=1` only for
interactive failure diagnosis.
