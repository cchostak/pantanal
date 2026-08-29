#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly ROOT_DIR
cluster_name="pantanal"

if ! command -v kind >/dev/null 2>&1 || ! kind get clusters | grep -Fxq "${cluster_name}"; then
  echo "integration tests skipped: kind cluster ${cluster_name} is not running"
  exit 0
fi

"${ROOT_DIR}/tests/integration/rbac-test.sh"
"${ROOT_DIR}/tests/integration/guardrail-test.sh"
"${ROOT_DIR}/tests/integration/trigger-test.sh"

kubectl --namespace sample-app wait --for=condition=Available --timeout=10m rollout/sample-app
kubectl --namespace sample-app port-forward service/sample-app 18080:80 >"${TMPDIR:-/tmp}/pantanal-port-forward.log" 2>&1 &
port_forward_pid=$!
trap 'kill "${port_forward_pid}" >/dev/null 2>&1 || true' EXIT

for _ in $(seq 1 30); do
  if curl --fail --silent http://127.0.0.1:18080/readyz | grep -Fxq ready; then
    break
  fi
  sleep 1
done
curl --fail --silent http://127.0.0.1:18080/healthz | grep -Fxq ok
curl --fail --silent http://127.0.0.1:18080/ | jq -e '.service == "sample-app" and (.version | length > 0)' >/dev/null
test "$(curl --silent --output /dev/null --write-out '%{http_code}' --request POST http://127.0.0.1:18080/)" = 405

echo "control-plane integration checks passed"
