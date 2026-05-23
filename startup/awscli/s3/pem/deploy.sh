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

if [[ ! -f "$ROOT_DIR/${EC2_API_GATEWAY_KEY_NAME_AZ1}.pem" || \
      ! -f "$ROOT_DIR/${EC2_API_GATEWAY_KEY_NAME_AZ2}.pem" || \
      ! -f "$ROOT_DIR/${EC2_USER_SERVICE_KEY_NAME_AZ1}.pem" || \
      ! -f "$ROOT_DIR/${EC2_USER_SERVICE_KEY_NAME_AZ2}.pem" ]]; then
  echo "Missing one or more local PEM files in $ROOT_DIR."
  exit 1
fi

if aws s3api head-bucket --bucket "${AUTHIFY_S3_PEM_BUCKET}" >/dev/null 2>&1; then
  echo "PEM bucket $AUTHIFY_S3_PEM_BUCKET already exists, skipping creation."
else
  echo "Creating PEM bucket $AUTHIFY_S3_PEM_BUCKET ..."
  if [[ "${REGION}" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "${AUTHIFY_S3_PEM_BUCKET}" >/dev/null
  else
    aws s3api create-bucket \
      --bucket "${AUTHIFY_S3_PEM_BUCKET}" \
      --region "${REGION}" \
      --create-bucket-configuration "LocationConstraint=${REGION}" >/dev/null
  fi
fi

aws s3api put-public-access-block \
  --bucket "${AUTHIFY_S3_PEM_BUCKET}" \
  --public-access-block-configuration '{
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
  }' >/dev/null

aws s3api put-bucket-encryption \
  --bucket "${AUTHIFY_S3_PEM_BUCKET}" \
  --server-side-encryption-configuration '{
    "Rules":[{
      "ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}
    }]
  }' >/dev/null

aws s3 cp "$ROOT_DIR/${EC2_API_GATEWAY_KEY_NAME_AZ1}.pem" \
  "s3://${AUTHIFY_S3_PEM_BUCKET}/${EC2_API_GATEWAY_KEY_NAME_AZ1}.pem" \
  --sse AES256 >/dev/null
aws s3 cp "$ROOT_DIR/${EC2_API_GATEWAY_KEY_NAME_AZ2}.pem" \
  "s3://${AUTHIFY_S3_PEM_BUCKET}/${EC2_API_GATEWAY_KEY_NAME_AZ2}.pem" \
  --sse AES256 >/dev/null
aws s3 cp "$ROOT_DIR/${EC2_USER_SERVICE_KEY_NAME_AZ1}.pem" \
  "s3://${AUTHIFY_S3_PEM_BUCKET}/${EC2_USER_SERVICE_KEY_NAME_AZ1}.pem" \
  --sse AES256 >/dev/null
aws s3 cp "$ROOT_DIR/${EC2_USER_SERVICE_KEY_NAME_AZ2}.pem" \
  "s3://${AUTHIFY_S3_PEM_BUCKET}/${EC2_USER_SERVICE_KEY_NAME_AZ2}.pem" \
  --sse AES256 >/dev/null

grep -vE '^(AUTHIFY_S3_PEM_BUCKET)=' "$VARIABLES_FILE" > "$VARIABLES_FILE.tmp" || true
{
  cat "$VARIABLES_FILE.tmp"
  echo "AUTHIFY_S3_PEM_BUCKET=$AUTHIFY_S3_PEM_BUCKET"
} > "$VARIABLES_FILE"
rm -f "$VARIABLES_FILE.tmp"

echo "✅ PEM files uploaded to S3."
