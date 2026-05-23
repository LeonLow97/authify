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

require_non_empty() {
  local var_name="$1"
  if [[ -z "${!var_name:-}" ]]; then
    echo "Missing $var_name. Set it in $ROOT_DIR/.env or run the required deploy step first."
    exit 1
  fi
}

for required_var in \
  DB_NAME \
  RDS_ENDPOINT \
  MASTER_USERNAME \
  AUTHIFY_USER \
  MASTER_PASSWORD \
  AUTHIFY_USER_PASSWORD \
  AUTHIFY_S3_SCHEMA_BUCKET \
  AUTHIFY_S3_PEM_BUCKET \
  ELASTICACHE_ENDPOINT \
  AUTH_JWT_TOKEN_SECRET \
  AUTH_JWT_TOKEN_DOMAIN; do
  require_non_empty "$required_var"
done

aws ssm put-parameter \
  --name "/authify/rds/db-name" \
  --value "$DB_NAME" \
  --type String \
  --overwrite >/dev/null

aws ssm put-parameter \
  --name "/authify/rds/endpoint" \
  --value "$RDS_ENDPOINT" \
  --type String \
  --overwrite >/dev/null

aws ssm put-parameter \
  --name "/authify/rds/master-username" \
  --value "$MASTER_USERNAME" \
  --type String \
  --overwrite >/dev/null

aws ssm put-parameter \
  --name "/authify/rds/user" \
  --value "$AUTHIFY_USER" \
  --type String \
  --overwrite >/dev/null

aws ssm put-parameter \
  --name "/authify/rds/master-password" \
  --value "$MASTER_PASSWORD" \
  --type SecureString \
  --overwrite >/dev/null

aws ssm put-parameter \
  --name "/authify/rds/authify-user-password" \
  --value "$AUTHIFY_USER_PASSWORD" \
  --type SecureString \
  --overwrite >/dev/null

aws ssm put-parameter \
  --name "/authify/s3/bucket/schema" \
  --value "$AUTHIFY_S3_SCHEMA_BUCKET" \
  --type String \
  --overwrite >/dev/null

aws ssm put-parameter \
  --name "/authify/s3/bucket/pem" \
  --value "$AUTHIFY_S3_PEM_BUCKET" \
  --type String \
  --overwrite >/dev/null

aws ssm put-parameter \
  --name "/authify/elasticache/endpoint" \
  --value "$ELASTICACHE_ENDPOINT" \
  --type String \
  --overwrite >/dev/null

# Temporary workaround: our current ElastiCache cluster was created without Redis AUTH,
# so publishing a password here makes the app send AUTH and crash on startup.
# Re-enable this once the cache is recreated with TLS/auth and the clients are updated.
# if [[ -n "${ELASTICACHE_PASSWORD}" ]]; then
#   aws ssm put-parameter \
#     --name "/authify/elasticache/password" \
#     --value "$ELASTICACHE_PASSWORD" \
#     --type SecureString \
#     --overwrite >/dev/null
# else
#   aws ssm delete-parameter --name "/authify/elasticache/password" >/dev/null 2>&1 || true
# fi

aws ssm put-parameter \
  --name "/authify/auth/jwt-secret" \
  --value "$AUTH_JWT_TOKEN_SECRET" \
  --type SecureString \
  --overwrite >/dev/null

aws ssm put-parameter \
  --name "/authify/auth/jwt-domain" \
  --value "$AUTH_JWT_TOKEN_DOMAIN" \
  --type String \
  --overwrite >/dev/null

echo "✅ SSM parameters updated."
