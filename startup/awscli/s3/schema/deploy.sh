#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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

if [[ "${USER_SERVICE_SCHEMA_DIR}" = /* ]]; then
  SCHEMA_SOURCE="${USER_SERVICE_SCHEMA_DIR}"
else
  SCHEMA_SOURCE="${ROOT_DIR}/${USER_SERVICE_SCHEMA_DIR}"
fi

if aws s3api head-bucket --bucket "${AUTHIFY_S3_SCHEMA_BUCKET}" >/dev/null 2>&1; then
  echo "Schema bucket $AUTHIFY_S3_SCHEMA_BUCKET already exists, skipping creation."
else
  echo "Creating schema bucket $AUTHIFY_S3_SCHEMA_BUCKET ..."
  if [[ "${REGION}" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "${AUTHIFY_S3_SCHEMA_BUCKET}" >/dev/null
  else
    aws s3api create-bucket \
      --bucket "${AUTHIFY_S3_SCHEMA_BUCKET}" \
      --region "${REGION}" \
      --create-bucket-configuration "LocationConstraint=${REGION}" >/dev/null
  fi
fi

aws s3 cp "${SCHEMA_SOURCE}" "s3://${AUTHIFY_S3_SCHEMA_BUCKET}/users.sql" >/dev/null

grep -vE '^(AUTHIFY_S3_SCHEMA_BUCKET)=' "$VARIABLES_FILE" > "$VARIABLES_FILE.tmp" || true
{
  cat "$VARIABLES_FILE.tmp"
  echo "AUTHIFY_S3_SCHEMA_BUCKET=$AUTHIFY_S3_SCHEMA_BUCKET"
} > "$VARIABLES_FILE"
rm -f "$VARIABLES_FILE.tmp"

echo "✅ SQL schema uploaded to S3."
