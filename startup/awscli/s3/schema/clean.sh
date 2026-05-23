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

if aws s3api head-bucket --bucket "${AUTHIFY_S3_SCHEMA_BUCKET}" >/dev/null 2>&1; then
  aws s3 rm "s3://${AUTHIFY_S3_SCHEMA_BUCKET}" --recursive >/dev/null 2>&1 || true
  aws s3 rb "s3://${AUTHIFY_S3_SCHEMA_BUCKET}" --force >/dev/null 2>&1 || true
fi

grep -vE '^(AUTHIFY_S3_SCHEMA_BUCKET)=' "$VARIABLES_FILE" > "$VARIABLES_FILE.tmp" || true
mv "$VARIABLES_FILE.tmp" "$VARIABLES_FILE"

echo "✅ Schema bucket cleanup completed."
