#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
load_local_env

log "checking Go sources"
(
  cd "${ROOT_DIR}/sample-app"
  test -z "$(gofmt -l .)"
  go vet ./...
  go test -race ./...
)

log "checking shell sources"
mapfile -t shell_files < <(find "${ROOT_DIR}/scripts" "${ROOT_DIR}/platform-infra/scripts" "${ROOT_DIR}/tests" -type f -name '*.sh' -print | sort)
for script in "${shell_files[@]}"; do
  bash -n "${script}"
done
if has_command shellcheck; then
  shellcheck "${shell_files[@]}"
fi
if has_command shfmt; then
  shfmt -d -i 2 -ci "${shell_files[@]}"
fi

if has_command yamllint; then
  yamllint -c "${ROOT_DIR}/.yamllint.yml" "${ROOT_DIR}"
fi
if has_command markdownlint; then
  markdownlint --config "${ROOT_DIR}/.markdownlint.yaml" "${ROOT_DIR}/**/*.md" "${ROOT_DIR}"/*.md
fi
if has_command actionlint; then
  actionlint "${ROOT_DIR}/.github/workflows/"*.yml
fi

"${ROOT_DIR}/platform-infra/scripts/verify.sh"
log "all static checks passed"
