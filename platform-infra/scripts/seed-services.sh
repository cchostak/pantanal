#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
source "${SECRETS_DIR}/credentials.env"

require_commands curl git jq kubectl
wait_for_http http://gitea.localhost:30000/api/healthz
wait_for_http http://harbor.localhost:30003/api/v2.0/health

gitea_api=http://gitea.localhost:30000/api/v1
gitea_auth="platform:${GITEA_ADMIN_PASSWORD}"

create_gitea_user() {
  local username="$1"
  local password="$2"
  local email="$3"
  local status
  status="$(jq --null-input \
    --arg username "${username}" --arg password "${password}" --arg email "${email}" \
    '{username: $username, password: $password, email: $email,
      must_change_password: false, visibility: "private"}' |
    curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
      --user "${gitea_auth}" --header 'Content-Type: application/json' --data-binary @- \
      "${gitea_api}/admin/users")"
  if [[ "${status}" != "201" && "${status}" != "422" ]]; then
    echo "failed to create Gitea user ${username}: HTTP ${status}" >&2
    return 1
  fi
}

create_gitea_user build-bot "${GITEA_BUILD_PASSWORD}" build-bot@local.invalid
create_gitea_user argo-reader "${GITEA_ARGO_PASSWORD}" argo-reader@local.invalid
if ! curl --fail --silent --user "${gitea_auth}" \
  "${gitea_api}/repos/platform/sample-app" >/dev/null 2>&1; then
  curl --fail --silent --show-error --user "${gitea_auth}" \
    --header 'Content-Type: application/json' \
    --data '{"name":"sample-app","private":true,"default_branch":"main"}' \
    "${gitea_api}/user/repos" >/dev/null
fi

for collaborator in build-bot argo-reader; do
  permission="read"
  if [[ "${collaborator}" == "build-bot" ]]; then
    permission="write"
  fi
  jq --null-input --arg permission "${permission}" '{permission: $permission}' |
    curl --fail --silent --show-error --user "${gitea_auth}" \
      --request PUT --header 'Content-Type: application/json' --data-binary @- \
      "${gitea_api}/repos/platform/sample-app/collaborators/${collaborator}" >/dev/null
done

if [[ ! -d "${REPO_DIR}/.git" ]]; then
  git -C "${REPO_DIR}" init --initial-branch=main
  git -C "${REPO_DIR}" add .
  git -C "${REPO_DIR}" \
    -c user.name='Pantanal Bootstrap' \
    -c user.email='bootstrap@local.invalid' \
    commit -m 'feat: scaffold hermetic delivery platform'
fi

if ! git -C "${REPO_DIR}" remote get-url gitea >/dev/null 2>&1; then
  git -C "${REPO_DIR}" remote add gitea \
    http://gitea.localhost:30000/platform/sample-app.git
fi
git_credentials_file="${SECRETS_DIR}/gitea-credentials"
printf 'http://platform:%s@gitea.localhost:30000\n' "${GITEA_ADMIN_PASSWORD}" \
  >"${git_credentials_file}"
chmod 0600 "${git_credentials_file}"

listener_url=http://el-sample-app.ci.svc.cluster.local:8080
hook_exists="$(curl --fail --silent --user "${gitea_auth}" \
  "${gitea_api}/repos/platform/sample-app/hooks" |
  jq --arg url "${listener_url}" 'any(.[]; .config.url == $url)')"
if [[ "${hook_exists}" != "true" ]]; then
  jq --null-input --arg url "${listener_url}" '{
    type: "gitea", active: true, events: ["push"],
    config: {url: $url, content_type: "json"}
  }' | curl --fail --silent --show-error --user "${gitea_auth}" \
    --header 'Content-Type: application/json' --data-binary @- \
    "${gitea_api}/repos/platform/sample-app/hooks" >/dev/null
fi

curl --silent --output /dev/null --write-out '%{http_code}' \
  --user "admin:${HARBOR_ADMIN_PASSWORD}" \
  --header 'Content-Type: application/json' \
  --data '{"project_name":"library","public":false}' \
  http://harbor.localhost:30003/api/v2.0/projects | grep -Eq '^(201|409)$'

robot_status="$(jq --null-input \
  --arg name pantanal-ci --arg secret "${HARBOR_ROBOT_SECRET}" \
  '{name: $name, description: "Pantanal CI push/pull identity", duration: -1,
    disable: false, level: "system", secret: $secret,
    permissions: [{kind: "project", namespace: "library", access: [
      {resource: "repository", action: "pull"},
      {resource: "repository", action: "push"},
      {resource: "scan", action: "create"}
    ]}]}' | curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
  --user "admin:${HARBOR_ADMIN_PASSWORD}" --header 'Content-Type: application/json' \
  --data-binary @- http://harbor.localhost:30003/api/v2.0/robots)"
if [[ "${robot_status}" != "201" && "${robot_status}" != "409" ]]; then
  echo "failed to create Harbor robot account: HTTP ${robot_status}" >&2
  exit 1
fi

robot_id="$(curl --fail --silent --user "admin:${HARBOR_ADMIN_PASSWORD}" \
  http://harbor.localhost:30003/api/v2.0/robots |
  jq --arg name "${HARBOR_ROBOT_NAME}" -er \
    '[.[] | select(.name == $name) | .id][0]')"
robot_secret_status="$(jq --null-input --arg secret "${HARBOR_ROBOT_SECRET}" \
  '{secret: $secret}' |
  curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
    --request PATCH --user "admin:${HARBOR_ADMIN_PASSWORD}" \
    --header 'Content-Type: application/json' --data-binary @- \
    "http://harbor.localhost:30003/api/v2.0/robots/${robot_id}")"
if [[ "${robot_secret_status}" != "200" ]]; then
  echo "failed to synchronize Harbor robot secret: HTTP ${robot_secret_status}" >&2
  exit 1
fi

kubectl apply -f "${REPO_DIR}/sample-app/deploy/argocd/project.yaml"
kubectl apply -f "${REPO_DIR}/sample-app/deploy/argocd/application.yaml"

# Create the branch only after the webhook, identities, secrets, and policies
# are ready. The initial push starts CI without mutating developer history.
git -C "${REPO_DIR}" \
  -c credential.helper="store --file=${git_credentials_file}" \
  push "http://gitea.localhost:30000/platform/sample-app.git" \
  HEAD:main
