.DEFAULT_GOAL := help

.PHONY: help bootstrap teardown verify check fmt test test-unit test-integration test-smoke scan doctor app-test app-image clean-test-artifacts

help: ## Show available targets.
	@awk 'BEGIN {FS = ":.*## "; printf "Pantanal targets:\n"} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

bootstrap: ## Create or reconcile the local delivery platform.
	nix develop ./platform-infra --command ./platform-infra/scripts/bootstrap.sh

teardown: ## Delete the Pantanal kind cluster.
	nix develop ./platform-infra --command ./platform-infra/scripts/teardown.sh

verify: ## Verify a running Pantanal control plane.
	nix develop ./platform-infra --command ./platform-infra/scripts/verify.sh

check: ## Run all non-mutating format, lint, and static checks.
	nix develop ./platform-infra --command ./scripts/check.sh

fmt: ## Format source and configuration files.
	nix develop ./platform-infra --command ./scripts/fmt.sh

test: ## Run unit and policy tests.
	nix develop ./platform-infra --command ./scripts/test.sh

test-unit: ## Run Go unit tests with race detection and coverage.
	cd sample-app && go test -race -coverprofile=../coverage.out ./...

test-integration: ## Run checks against an already-running control plane.
	./tests/integration/control-plane-test.sh

test-smoke: ## Bootstrap, exercise, and tear down an isolated end-to-end environment.
	nix develop ./platform-infra --command ./tests/smoke_test.sh

scan: ## Run secret, dependency, vulnerability, and configuration scans.
	nix develop ./platform-infra --command ./scripts/scan.sh

doctor: ## Diagnose local prerequisites, Docker, network, and environment configuration.
	./scripts/doctor.sh

app-test: test-unit ## Backwards-compatible alias for application tests.

app-image: ## Build the deterministic application OCI archive.
	nix build ./sample-app#container

clean-test-artifacts: ## Remove generated local test reports and coverage data.
	rm -f ./coverage.out ./coverage.html
	rm -rf ./reports ./.pantanal-smoke-state
