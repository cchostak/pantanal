#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
cluster_name="pantanal"
owns_cluster=false

collect_diagnostics() {
  mkdir -p "${ROOT_DIR}/.pantanal-smoke-state"
  kubectl get pods --all-namespaces -o wide >"${ROOT_DIR}/.pantanal-smoke-state/pods.txt" 2>&1 || true
  kubectl --namespace ci get pipelineruns -o yaml >"${ROOT_DIR}/.pantanal-smoke-state/pipelineruns.yaml" 2>&1 || true
  kubectl --namespace argocd get applications -o yaml >"${ROOT_DIR}/.pantanal-smoke-state/applications.yaml" 2>&1 || true
}

cleanup() {
  local status=$?
  if ((status != 0)); then
    collect_diagnostics
  fi
  if [[ "${owns_cluster}" == "true" && "${PANTANAL_KEEP_SMOKE_CLUSTER:-0}" != "1" ]]; then
    "${ROOT_DIR}/platform-infra/scripts/teardown.sh" || true
  fi
  exit "${status}"
}
trap cleanup EXIT INT TERM

if ! kind get clusters | grep -Fxq "${cluster_name}"; then
  owns_cluster=true
  "${ROOT_DIR}/platform-infra/scripts/bootstrap.sh"
else
  echo "using existing cluster ${cluster_name}; it will not be deleted"
fi

"${ROOT_DIR}/tests/integration/control-plane-test.sh"
echo "end-to-end smoke test passed"
