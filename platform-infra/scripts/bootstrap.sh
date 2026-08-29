#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
set -o allexport
source "${INFRA_DIR}/versions.env"
set +o allexport

require_commands cosign curl docker git helm helmfile jq kind kubectl kustomize openssl

"${SCRIPT_DIR}/generate-credentials.sh"
source "${SECRETS_DIR}/credentials.env"
export GITEA_ADMIN_PASSWORD HARBOR_ADMIN_PASSWORD

if ! kind get clusters | grep -Fxq pantanal; then
  kind create cluster --config "${INFRA_DIR}/kind-config.yaml" \
    --image "${KIND_NODE_IMAGE}"
fi

helmfile --file "${INFRA_DIR}/helmfile.yaml" sync

kubectl apply -f \
  "https://infra.tekton.dev/tekton-releases/pipeline/previous/${TEKTON_PIPELINES_VERSION}/release.yaml"
kubectl apply -f \
  "https://infra.tekton.dev/tekton-releases/triggers/previous/${TEKTON_TRIGGERS_VERSION}/release.yaml"
kubectl apply -f \
  "https://infra.tekton.dev/tekton-releases/triggers/previous/${TEKTON_INTERCEPTORS_VERSION}/interceptors.yaml"

kubectl wait --for=condition=Available --timeout=5m \
  deployment/tekton-pipelines-controller -n tekton-pipelines
kubectl wait --for=condition=Available --timeout=5m \
  deployment/tekton-triggers-controller -n tekton-pipelines
kubectl wait --for=condition=Available --timeout=5m \
  deployment/tekton-events-controller -n tekton-pipelines

kubectl apply -k "${INFRA_DIR}/tekton"

kubectl wait --for=condition=Ready --timeout=10m pod --all -n gitea
kubectl wait --for=condition=Ready --timeout=10m pod --all -n harbor
kubectl wait --for=condition=Ready --timeout=10m pod --all -n argocd
kubectl wait --for=condition=Available --timeout=10m deployment/kyverno-admission-controller -n kyverno
"${SCRIPT_DIR}/create-secrets.sh"
kubectl apply -k "${INFRA_DIR}/policies"
"${SCRIPT_DIR}/seed-services.sh"

echo
echo "Control plane ready"
echo "Gitea:  http://gitea.localhost:30000"
echo "Harbor: http://harbor.localhost:30003"
echo "Argo:   http://argocd.localhost:30080"
echo "Local credentials: ${SECRETS_DIR}/credentials.env"
echo "Argo initial password is stored only in the in-cluster secret (not printed)."
