#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1090,SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

cluster_name="pantanal"
if kind get clusters | grep -Fxq "${cluster_name}"; then
  kind delete cluster --name "${cluster_name}"
else
  echo "cluster ${cluster_name} does not exist; nothing to delete"
fi
