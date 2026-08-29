#!/usr/bin/env bash
set -euo pipefail

message_file="${1:?commit message file is required}"
first_line="$(head -n 1 "${message_file}")"

if [[ "${first_line}" =~ ^(Merge|Revert)\  ]]; then
  exit 0
fi

if [[ ! "${first_line}" =~ ^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([a-z0-9._/-]+\))?(!)?:\ .+ ]]; then
  echo "commit message must follow Conventional Commits: type(scope): summary" >&2
  exit 1
fi
