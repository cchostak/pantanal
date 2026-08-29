#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

require_commands go kustomize

test -f "${REPO_DIR}/sample-app/flake.lock"
test -f "${INFRA_DIR}/flake.lock"
(cd "${REPO_DIR}/sample-app" && go test ./...)
kustomize build "${INFRA_DIR}/tekton" >/dev/null
kustomize build "${INFRA_DIR}/policies" >/dev/null
kustomize build "${REPO_DIR}/sample-app/deploy/overlays/local" >/dev/null

for script in "${SCRIPT_DIR}"/*.sh; do
  bash -n "${script}"
done

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "${SCRIPT_DIR}"/*.sh
fi

"${REPO_DIR}/tests/policy_test.sh"

if kind get clusters 2>/dev/null | grep -Fxq pantanal; then
  kubectl auth can-i create pipelineruns.tekton.dev \
    --as=system:serviceaccount:ci:triggers-bot --namespace ci | grep -Fxq yes
  kubectl auth can-i impersonate serviceaccounts/build-bot \
    --as=system:serviceaccount:ci:triggers-bot --namespace ci | grep -Fxq yes
  kubectl auth can-i get secrets \
    --as=system:serviceaccount:ci:triggers-bot --namespace ci | grep -Fxq no
fi

echo "Static validation passed"
