#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR

log() {
  printf 'pantanal: %s\n' "$*" >&2
}

die() {
  log "error: $*"
  exit 1
}

has_command() {
  command -v "$1" >/dev/null 2>&1
}

load_local_env() {
  local env_file="${ROOT_DIR}/.env"
  local line
  local key
  local value
  if [[ ! -f "${env_file}" ]]; then
    return 0
  fi
  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ -z "${line}" || "${line}" == \#* ]]; then
      continue
    fi
    if [[ ! "${line}" =~ ^[A-Z][A-Z0-9_]*=[^[:cntrl:]]*$ ]]; then
      die ".env contains unsupported syntax; use KEY=value lines only"
    fi
    key="${line%%=*}"
    value="${line#*=}"
    export "${key}=${value}"
  done <"${env_file}"
}
