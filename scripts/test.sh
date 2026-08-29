#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

log "running unit tests"
(
  cd "${ROOT_DIR}/sample-app"
  go test -race -coverprofile="${ROOT_DIR}/coverage.out" ./...
)

log "running policy and manifest tests"
"${ROOT_DIR}/tests/policy_test.sh"
"${ROOT_DIR}/tests/integration/control-plane-test.sh"
