#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly ROOT_DIR
expected_revision="$(git -C "${ROOT_DIR}" rev-parse HEAD)"

for _ in $(seq 1 120); do
  run_name="$(kubectl --namespace ci get pipelineruns --sort-by=.metadata.creationTimestamp \
    --output=jsonpath='{.items[-1:].metadata.name}' 2>/dev/null || true)"
  if [[ -n "${run_name}" ]]; then
    revision="$(kubectl --namespace ci get pipelinerun "${run_name}" \
      --output=jsonpath='{.spec.params[?(@.name=="revision")].value}')"
    if [[ "${revision}" == "${expected_revision}" ]]; then
      status="$(kubectl --namespace ci get pipelinerun "${run_name}" \
        --output=jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}')"
      case "${status}" in
        True)
          echo "Gitea payload reached PipelineRun ${run_name} at ${revision}"
          exit 0
          ;;
        False)
          reason="$(kubectl --namespace ci get pipelinerun "${run_name}" \
            --output=jsonpath='{.status.conditions[?(@.type=="Succeeded")].message}')"
          echo "PipelineRun ${run_name} failed: ${reason}" >&2
          exit 1
          ;;
      esac
    fi
  fi
  sleep 5
done

echo "timed out waiting for a PipelineRun for ${expected_revision}" >&2
exit 1
