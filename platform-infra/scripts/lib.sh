#!/usr/bin/env bash
# shellcheck disable=SC2034

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_DIR="$(cd "${INFRA_DIR}/.." && pwd)"
SECRETS_DIR="${INFRA_DIR}/secrets"

require_commands() {
  local command_name
  for command_name in "$@"; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
      echo "missing required command: ${command_name}" >&2
      return 1
    fi
  done
}

wait_for_http() {
  local url="$1"
  local attempts="${2:-${PANTANAL_HTTP_RETRIES:-60}}"
  local retry_seconds="${PANTANAL_HTTP_RETRY_SECONDS:-5}"
  local attempt
  for ((attempt = 1; attempt <= attempts; attempt++)); do
    if curl --fail --silent --show-error "${url}" >/dev/null 2>&1; then
      return 0
    fi
    sleep "${retry_seconds}"
  done
  echo "timed out waiting for ${url}" >&2
  return 1
}

apply_secret() {
  local namespace="$1"
  shift
  kubectl --namespace "${namespace}" create secret "$@" \
    --dry-run=client --output=yaml | kubectl apply -f -
}
