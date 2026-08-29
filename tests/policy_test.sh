#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if ! grep -Eq -- "${pattern}" "${file}"; then
    echo "policy assertion failed: ${message}" >&2
    return 1
  fi
}

assert_literal() {
  local file="$1"
  local text="$2"
  local message="$3"
  if ! grep -Fq -- "${text}" "${file}"; then
    echo "policy assertion failed: ${message}" >&2
    return 1
  fi
}

rbac="${ROOT_DIR}/platform-infra/tekton/rbac.yaml"
trigger="${ROOT_DIR}/platform-infra/tekton/triggers.yaml"
rollout="${ROOT_DIR}/sample-app/deploy/base/rollout.yaml"
policy="${ROOT_DIR}/platform-infra/policies/workload-security.yaml"

assert_contains "${rbac}" 'resourceNames: \["build-bot"\]' "impersonation must be limited to build-bot"
assert_contains "${rbac}" 'automountServiceAccountToken: false' "build jobs must not mount API tokens"
assert_contains "${trigger}" "repository.full_name == 'platform/sample-app'" "CEL must bind payloads to the repository"
assert_literal "${trigger}" "body.after.matches('^[a-f0-9]{40}$')" "CEL must validate commit SHAs"
assert_contains "${trigger}" "startsWith\('chore\(deploy\):'\)" "CEL must block deployment loops"
assert_contains "${rollout}" 'runAsNonRoot: true' "workload must run as non-root"
assert_contains "${rollout}" 'readOnlyRootFilesystem: true' "workload root filesystem must be read-only"
assert_contains "${rollout}" 'path: /readyz' "readiness must use the dedicated endpoint"
assert_contains "${policy}" 'validationFailureAction: Enforce' "admission policy must enforce"
assert_contains "${policy}" 'image: "\*@sha256:\*"' "admission policy must require digests"

if command -v kustomize >/dev/null 2>&1; then
  kustomize build "${ROOT_DIR}/platform-infra/tekton" >/dev/null
  kustomize build "${ROOT_DIR}/platform-infra/policies" >/dev/null
  kustomize build "${ROOT_DIR}/sample-app/deploy/overlays/local" >/dev/null
fi

echo "policy assertions passed"
