#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

gofmt -w "${ROOT_DIR}/sample-app"
mapfile -t shell_files < <(find "${ROOT_DIR}/scripts" "${ROOT_DIR}/platform-infra/scripts" "${ROOT_DIR}/tests" -type f -name '*.sh' -print | sort)
if has_command shfmt; then
  shfmt -w -i 2 -ci "${shell_files[@]}"
else
  log "shfmt unavailable; shell files were not reformatted"
fi
if has_command nixfmt; then
  find "${ROOT_DIR}" -type f -name '*.nix' -print0 | xargs -0 nixfmt
fi
