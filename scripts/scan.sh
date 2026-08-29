#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
mkdir -p "${ROOT_DIR}/reports"

has_command gitleaks || die "gitleaks is required (run make doctor)"
has_command trivy || die "trivy is required (run make doctor)"
has_command govulncheck || die "govulncheck is required (run make doctor)"

gitleaks git --redact --no-banner --report-format sarif --report-path "${ROOT_DIR}/reports/gitleaks.sarif" "${ROOT_DIR}"
trivy filesystem --scanners vuln,secret,misconfig --exit-code 1 --severity HIGH,CRITICAL "${ROOT_DIR}"
(cd "${ROOT_DIR}/sample-app" && govulncheck ./...)
