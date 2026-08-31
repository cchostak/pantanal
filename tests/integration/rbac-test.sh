#!/usr/bin/env bash
set -euo pipefail

allowed() {
  local result
  result="$(kubectl auth can-i "$@" --as=system:serviceaccount:ci:triggers-bot --namespace ci)"
  [[ "${result}" == "yes" ]] || {
    echo "expected permission was denied: $*" >&2
    return 1
  }
}

denied() {
  local result
  result="$(kubectl auth can-i "$@" --as=system:serviceaccount:ci:triggers-bot --namespace ci || true)"
  [[ "${result}" == "no" ]] || {
    echo "unexpected permission was granted: $*" >&2
    return 1
  }
}

allowed create pipelineruns.tekton.dev
allowed impersonate serviceaccounts/build-bot
allowed get clusterinterceptors.triggers.tekton.dev
denied impersonate serviceaccounts/default
denied get secrets
denied create deployments.apps
