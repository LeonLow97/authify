#!/bin/bash

set -euo pipefail

required_ssm_parameter() {
  local name="$1"
  local decrypt="${2:-false}"
  local args=(--name "${name}" --query 'Parameter.Value' --output text)

  if [[ "${decrypt}" == "true" ]]; then
    args+=(--with-decryption)
  fi

  aws ssm get-parameter "${args[@]}"
}

if [[ -z "${AWS_DEFAULT_REGION:-}" && -z "${AWS_REGION:-}" ]]; then
  METADATA_TOKEN="$(curl -fsS --connect-timeout 1 --max-time 2 -X PUT http://169.254.169.254/latest/api/token \
    -H 'X-aws-ec2-metadata-token-ttl-seconds: 21600' 2>/dev/null || true)"
  if [[ -n "${METADATA_TOKEN}" ]]; then
    AWS_DEFAULT_REGION="$(curl -fsS --connect-timeout 1 --max-time 2 -H "X-aws-ec2-metadata-token: ${METADATA_TOKEN}" \
      http://169.254.169.254/latest/meta-data/placement/region)"
    export AWS_DEFAULT_REGION
  fi
fi

DB_NAME="$(required_ssm_parameter /authify/rds/db-name)"
RDS_ENDPOINT="$(required_ssm_parameter /authify/rds/endpoint)"
MASTER_USERNAME="$(required_ssm_parameter /authify/rds/master-username)"
AUTHIFY_USER="$(required_ssm_parameter /authify/rds/user)"
MASTER_PASSWORD="$(required_ssm_parameter /authify/rds/master-password true)"
AUTHIFY_USER_PASSWORD="$(required_ssm_parameter /authify/rds/authify-user-password true)"
AUTHIFY_S3_SCHEMA_BUCKET="$(required_ssm_parameter /authify/s3/bucket/schema)"

sudo dnf install -y postgresql15

# This is the manual recovery path when RDS/app-user state drifts from SSM.
PGPASSWORD="${MASTER_PASSWORD}" psql -v ON_ERROR_STOP=1 -h "${RDS_ENDPOINT}" -U "${MASTER_USERNAME}" -d postgres \
  -v authify_user="${AUTHIFY_USER}" \
  -v authify_user_password="${AUTHIFY_USER_PASSWORD}" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'authify_user', :'authify_user_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'authify_user')
\gexec
SELECT format('ALTER ROLE %I WITH PASSWORD %L', :'authify_user', :'authify_user_password')
\gexec
SQL

PGPASSWORD="${MASTER_PASSWORD}" psql -v ON_ERROR_STOP=1 -h "${RDS_ENDPOINT}" -U "${MASTER_USERNAME}" -d postgres \
  -v db_name="${DB_NAME}" \
  -v authify_user="${AUTHIFY_USER}" <<'SQL'
SELECT format('CREATE DATABASE %I OWNER %I', :'db_name', :'authify_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'db_name')
\gexec
SQL

PGPASSWORD="${MASTER_PASSWORD}" psql -v ON_ERROR_STOP=1 -h "${RDS_ENDPOINT}" -U "${MASTER_USERNAME}" -d "${DB_NAME}" \
  -v authify_user="${AUTHIFY_USER}" \
  -v db_name="${DB_NAME}" <<'SQL'
SELECT format('GRANT ALL PRIVILEGES ON DATABASE %I TO %I', :'db_name', :'authify_user')
\gexec
SELECT format('GRANT ALL PRIVILEGES ON SCHEMA public TO %I', :'authify_user')
\gexec
SELECT format('GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO %I', :'authify_user')
\gexec
SELECT format('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO %I', :'authify_user')
\gexec
SELECT format('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO %I', :'authify_user')
\gexec
SQL

if [[ "$(PGPASSWORD="${AUTHIFY_USER_PASSWORD}" psql -h "${RDS_ENDPOINT}" -U "${AUTHIFY_USER}" -d "${DB_NAME}" -tAc "SELECT to_regclass('public.users')" | tr -d '[:space:]')" != "users" ]]; then
  aws s3 cp "s3://${AUTHIFY_S3_SCHEMA_BUCKET}/users.sql" /tmp/users.sql --no-cli-pager
  PGPASSWORD="${AUTHIFY_USER_PASSWORD}" psql -v ON_ERROR_STOP=1 -h "${RDS_ENDPOINT}" -U "${AUTHIFY_USER}" -d "${DB_NAME}" -f /tmp/users.sql
fi

echo "✅ Authify DB user and schema ensured."
