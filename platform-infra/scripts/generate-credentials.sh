#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

require_commands cosign openssl
mkdir -p "${SECRETS_DIR}"
chmod 0700 "${SECRETS_DIR}"

CREDENTIALS_FILE="${SECRETS_DIR}/credentials.env"
if [[ ! -f "${CREDENTIALS_FILE}" ]]; then
  {
    echo "GITEA_ADMIN_PASSWORD=$(openssl rand -hex 24)"
    echo "GITEA_BUILD_PASSWORD=$(openssl rand -hex 24)"
    echo "GITEA_ARGO_PASSWORD=$(openssl rand -hex 24)"
    echo "HARBOR_ADMIN_PASSWORD=$(openssl rand -hex 24)"
    echo "HARBOR_ROBOT_NAME='robot\$pantanal-ci'"
    echo "HARBOR_ROBOT_SECRET=A$(openssl rand -hex 23)a1"
    echo "COSIGN_PASSWORD=$(openssl rand -hex 24)"
  } >"${CREDENTIALS_FILE}"
  chmod 0600 "${CREDENTIALS_FILE}"
fi

source "${CREDENTIALS_FILE}"
if [[ ! -f "${SECRETS_DIR}/cosign.key" ]]; then
  COSIGN_PASSWORD="${COSIGN_PASSWORD}" cosign generate-key-pair \
    --output-key-prefix "${SECRETS_DIR}/cosign"
  chmod 0600 "${SECRETS_DIR}/cosign.key"
fi
