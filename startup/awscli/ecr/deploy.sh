#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
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
CONFIG_ECR_AUTHIFY_REPOSITORY="${ECR_AUTHIFY_REPOSITORY}"
CONFIG_DOCKER_AUTHIFY_API_GATEWAY_IMAGE_TAG="${DOCKER_AUTHIFY_API_GATEWAY_IMAGE_TAG}"
CONFIG_DOCKER_AUTHIFY_USER_SERVICE_IMAGE_TAG="${DOCKER_AUTHIFY_USER_SERVICE_IMAGE_TAG}"
VARIABLES_FILE="${VARIABLES_FILE:-variables.env}"
if [[ "$VARIABLES_FILE" != /* ]]; then
  VARIABLES_FILE="$ROOT_DIR/$VARIABLES_FILE"
fi
touch "$VARIABLES_FILE"
source "$VARIABLES_FILE"
set +a

ECR_AUTHIFY_REPOSITORY="${CONFIG_ECR_AUTHIFY_REPOSITORY}"
DOCKER_AUTHIFY_API_GATEWAY_IMAGE_TAG="${CONFIG_DOCKER_AUTHIFY_API_GATEWAY_IMAGE_TAG}"
DOCKER_AUTHIFY_USER_SERVICE_IMAGE_TAG="${CONFIG_DOCKER_AUTHIFY_USER_SERVICE_IMAGE_TAG}"

if [[ -z "${AWS_ACCOUNT_ID:-}" ]]; then
  AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query 'Account' --output text)"
fi

if aws ecr describe-repositories --repository-names "${ECR_AUTHIFY_REPOSITORY}" --region "${REGION}" >/dev/null 2>&1; then
  echo "ECR repository $ECR_AUTHIFY_REPOSITORY already exists, skipping creation."
else
  echo "Creating ECR repository $ECR_AUTHIFY_REPOSITORY ..."
  aws ecr create-repository \
    --repository-name "${ECR_AUTHIFY_REPOSITORY}" \
    --region "${REGION}" >/dev/null
fi

aws ecr get-login-password --region "${REGION}" \
  | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

ECR_API_GATEWAY_IMAGE="${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_AUTHIFY_REPOSITORY}:${DOCKER_AUTHIFY_API_GATEWAY_IMAGE_TAG}"
ECR_USER_SERVICE_IMAGE="${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_AUTHIFY_REPOSITORY}:${DOCKER_AUTHIFY_USER_SERVICE_IMAGE_TAG}"

cd "${PROJECT_ROOT}/api-gateway"
docker build -f Dockerfile --platform linux/amd64 -t "${DOCKER_AUTHIFY_API_GATEWAY_IMAGE}" .
docker tag "${DOCKER_AUTHIFY_API_GATEWAY_IMAGE}" "${ECR_API_GATEWAY_IMAGE}"
docker push "${ECR_API_GATEWAY_IMAGE}"

cd "${PROJECT_ROOT}/user-service"
docker build -f Dockerfile --platform linux/amd64 -t "${DOCKER_AUTHIFY_USER_SERVICE_IMAGE}" .
docker tag "${DOCKER_AUTHIFY_USER_SERVICE_IMAGE}" "${ECR_USER_SERVICE_IMAGE}"
docker push "${ECR_USER_SERVICE_IMAGE}"

grep -vE '^(AWS_ACCOUNT_ID|ECR_API_GATEWAY_IMAGE|ECR_USER_SERVICE_IMAGE|DOCKER_AUTHIFY_API_GATEWAY_IMAGE_TAG|DOCKER_AUTHIFY_USER_SERVICE_IMAGE_TAG)=' "$VARIABLES_FILE" > "$VARIABLES_FILE.tmp" || true
{
  cat "$VARIABLES_FILE.tmp"
  echo "AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID"
  echo "ECR_API_GATEWAY_IMAGE=$ECR_API_GATEWAY_IMAGE"
  echo "ECR_USER_SERVICE_IMAGE=$ECR_USER_SERVICE_IMAGE"
} > "$VARIABLES_FILE"
rm -f "$VARIABLES_FILE.tmp"

echo "✅ ECR images pushed."
