#!/usr/bin/env bash
set -euo pipefail

if kubectl --namespace sample-app apply -f - >/dev/null 2>&1 <<'YAML'; then
apiVersion: v1
kind: Pod
metadata:
  name: forbidden-privileged-test
spec:
  containers:
    - name: test
      image: busybox:latest
      command: [sleep, "30"]
      securityContext:
        privileged: true
YAML
  kubectl --namespace sample-app delete pod forbidden-privileged-test --ignore-not-found >/dev/null
  echo "guardrail failed: privileged mutable-tag workload was admitted" >&2
  exit 1
fi

echo "admission guardrail rejected an unsafe workload"
