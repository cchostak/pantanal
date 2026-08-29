#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

require_commands jq kubectl
"${SCRIPT_DIR}/generate-credentials.sh"

set -o allexport
source "${SECRETS_DIR}/credentials.env"
set +o allexport

kubectl create namespace ci --dry-run=client --output=yaml | kubectl apply -f -
kubectl create namespace sample-app --dry-run=client --output=yaml | kubectl apply -f -

git_credentials="http://build-bot:${GITEA_BUILD_PASSWORD}@gitea-http.gitea.svc.cluster.local:3000"
apply_secret ci generic gitea-git-auth \
  --from-literal=.git-credentials="${git_credentials}"

registry_auth="$(printf '%s:%s' "${HARBOR_ROBOT_NAME}" "${HARBOR_ROBOT_SECRET}" | base64 | tr -d '\n')"
jq --null-input --arg auth "${registry_auth}" '{auths: {
  "harbor.harbor.svc.cluster.local": {auth: $auth},
  "harbor.localhost:30003": {auth: $auth}
}}' >"${SECRETS_DIR}/docker-config.json"

apply_secret ci generic harbor-registry-auth \
  --type=kubernetes.io/dockerconfigjson \
  --from-file=.dockerconfigjson="${SECRETS_DIR}/docker-config.json"
apply_secret sample-app generic harbor-pull \
  --type=kubernetes.io/dockerconfigjson \
  --from-file=.dockerconfigjson="${SECRETS_DIR}/docker-config.json"
apply_secret ci generic cosign-signing-key \
  --from-file=cosign.key="${SECRETS_DIR}/cosign.key" \
  --from-file=cosign.pub="${SECRETS_DIR}/cosign.pub" \
  --from-literal=password="${COSIGN_PASSWORD}"

apply_secret argocd generic sample-app-repository \
  --from-literal=type=git \
  --from-literal=url=http://gitea-http.gitea.svc.cluster.local:3000/platform/sample-app.git \
  --from-literal=username=argo-reader \
  --from-literal=password="${GITEA_ARGO_PASSWORD}"
kubectl --namespace argocd label secret sample-app-repository \
  argocd.argoproj.io/secret-type=repository --overwrite
