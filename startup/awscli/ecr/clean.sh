#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f "$ROOT_DIR/.env.template" ]]; then
  echo "Missing $ROOT_DIR/.env.template."
  exit 1
fi

set -a
source "$ROOT_DIR/.env.template"
if [[ -f "$ROOT_DIR/.env" ]]; then
  source "$ROOT_DIR/.env"
fi
VARIABLES_FILE="${VARIABLES_FILE:-variables.env}"
if [[ "$VARIABLES_FILE" != /* ]]; then
  VARIABLES_FILE="$ROOT_DIR/$VARIABLES_FILE"
fi
touch "$VARIABLES_FILE"
source "$VARIABLES_FILE"
set +a

docker rmi -f "${DOCKER_AUTHIFY_API_GATEWAY_IMAGE}" >/dev/null 2>&1 || true
docker rmi -f "${DOCKER_AUTHIFY_USER_SERVICE_IMAGE}" >/dev/null 2>&1 || true

if aws ecr describe-repositories --repository-names "${ECR_AUTHIFY_REPOSITORY}" --region "${REGION}" >/dev/null 2>&1; then
  aws ecr delete-repository \
    --repository-name "${ECR_AUTHIFY_REPOSITORY}" \
    --region "${REGION}" \
    --force >/dev/null 2>&1 || true
fi

grep -vE '^(AWS_ACCOUNT_ID|ECR_API_GATEWAY_IMAGE|ECR_USER_SERVICE_IMAGE|DOCKER_AUTHIFY_API_GATEWAY_IMAGE_TAG|DOCKER_AUTHIFY_USER_SERVICE_IMAGE_TAG)=' "$VARIABLES_FILE" > "$VARIABLES_FILE.tmp" || true
mv "$VARIABLES_FILE.tmp" "$VARIABLES_FILE"

echo "✅ ECR cleanup completed."
