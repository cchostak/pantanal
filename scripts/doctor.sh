#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
load_local_env

required=(bash curl docker git go make nix)
optional=(actionlint gitleaks govulncheck markdownlint pre-commit shellcheck shfmt trivy yamllint)
failed=0

for tool in "${required[@]}"; do
  if has_command "${tool}"; then
    printf 'ok       %s\n' "${tool}"
  else
    printf 'missing  %s (required)\n' "${tool}"
    failed=1
  fi
done
for tool in "${optional[@]}"; do
  if has_command "${tool}"; then
    printf 'ok       %s\n' "${tool}"
  else
    printf 'missing  %s (provided by the Nix development shell)\n' "${tool}"
  fi
done

if docker info >/dev/null 2>&1; then
  printf 'ok       Docker daemon\n'
else
  printf 'failed   Docker daemon is not reachable\n'
  failed=1
fi

if curl --fail --silent --show-error --head --max-time 10 https://github.com >/dev/null; then
  printf 'ok       network access to GitHub\n'
else
  printf 'failed   cannot reach GitHub\n'
  failed=1
fi

if [[ -f "${ROOT_DIR}/.env" ]]; then
  allowed='^(LISTEN_ADDRESS|READ_HEADER_TIMEOUT|READ_TIMEOUT|WRITE_TIMEOUT|IDLE_TIMEOUT|SHUTDOWN_TIMEOUT|LOG_LEVEL|PANTANAL_HTTP_RETRIES|PANTANAL_HTTP_RETRY_SECONDS|PANTANAL_KEEP_SMOKE_CLUSTER)='
  if grep -Ev '^(#|[[:space:]]*$)' "${ROOT_DIR}/.env" | grep -Ev "${allowed}" | grep -q .; then
    printf 'failed   .env contains an undocumented variable\n'
    failed=1
  else
    printf 'ok       .env syntax and variable names\n'
  fi
else
  printf 'info     .env absent; documented defaults apply\n'
fi

if command -v ss >/dev/null 2>&1; then
  for port in 30000 30003 30022 30080; do
    if ss -ltnH | awk '{print $4}' | grep -Eq "[:.]${port}$"; then
      printf 'failed   TCP port %s is already in use\n' "${port}"
      failed=1
    else
      printf 'ok       TCP port %s is available\n' "${port}"
    fi
  done
fi

exit "${failed}"
