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

if [[ -z "${VPC_ID:-}" || -z "${PRIVATE_RDS_SUBNET_AZ1_ID:-}" || -z "${PRIVATE_RDS_SUBNET_AZ2_ID:-}" || -z "${RDS_SG_ID:-}" ]]; then
  echo "Missing VPC or subnet or security group values. Run VPC and security-group scripts first."
  exit 1
fi

if aws rds describe-db-subnet-groups --db-subnet-group-name "${DB_SUBNET_GROUP_NAME}" >/dev/null 2>&1; then
  echo "RDS subnet group $DB_SUBNET_GROUP_NAME already exists, skipping creation."
else
  echo "Creating RDS subnet group $DB_SUBNET_GROUP_NAME ..."
  aws rds create-db-subnet-group \
    --db-subnet-group-name "${DB_SUBNET_GROUP_NAME}" \
    --db-subnet-group-description "Authify RDS subnet group in ${VPC_ID}" \
    --subnet-ids "${PRIVATE_RDS_SUBNET_AZ1_ID}" "${PRIVATE_RDS_SUBNET_AZ2_ID}" \
    --region "${REGION}" >/dev/null
fi

if aws rds describe-db-parameter-groups --db-parameter-group-name "${DB_PARAMETER_GROUP_NAME}" >/dev/null 2>&1; then
  echo "RDS parameter group $DB_PARAMETER_GROUP_NAME already exists, ensuring rds.force_ssl=0."
else
  echo "Creating RDS parameter group $DB_PARAMETER_GROUP_NAME ..."
  aws rds create-db-parameter-group \
    --db-parameter-group-name "${DB_PARAMETER_GROUP_NAME}" \
    --db-parameter-group-family "${DB_PARAMETER_GROUP_FAMILY}" \
    --description "Authify RDS parameter group" \
    --region "${REGION}" >/dev/null
fi

aws rds modify-db-parameter-group \
  --db-parameter-group-name "${DB_PARAMETER_GROUP_NAME}" \
  --parameters "ParameterName=rds.force_ssl,ParameterValue=0,ApplyMethod=immediate" \
  --region "${REGION}" >/dev/null

if aws rds describe-db-instances --db-instance-identifier "${RDS_INSTANCE_IDENTIFIER}" >/dev/null 2>&1; then
  echo "RDS instance $RDS_INSTANCE_IDENTIFIER already exists, ensuring parameter group attachment."
  CURRENT_PARAMETER_GROUP="$(aws rds describe-db-instances \
    --db-instance-identifier "${RDS_INSTANCE_IDENTIFIER}" \
    --region "${REGION}" \
    --query 'DBInstances[0].DBParameterGroups[0].DBParameterGroupName' \
    --output text)"
  if [[ "${CURRENT_PARAMETER_GROUP}" != "${DB_PARAMETER_GROUP_NAME}" ]]; then
    aws rds modify-db-instance \
      --db-instance-identifier "${RDS_INSTANCE_IDENTIFIER}" \
      --db-parameter-group-name "${DB_PARAMETER_GROUP_NAME}" \
      --apply-immediately \
      --region "${REGION}" >/dev/null
  fi
else
  echo "Creating RDS instance $RDS_INSTANCE_IDENTIFIER ..."
  RDS_MULTI_AZ_FLAG="--no-multi-az"
  if [[ "${RDS_MULTI_AZ}" == "true" ]]; then
    RDS_MULTI_AZ_FLAG="--multi-az"
  fi
  aws rds create-db-instance \
    --db-instance-identifier "${RDS_INSTANCE_IDENTIFIER}" \
    --db-instance-class "${DB_INSTANCE_CLASS}" \
    --engine "${ENGINE}" \
    --engine-version "${DB_ENGINE_VERSION}" \
    --allocated-storage "${ALLOCATED_STORAGE}" \
    --master-username "${MASTER_USERNAME}" \
    --master-user-password "${MASTER_PASSWORD}" \
    --vpc-security-group-ids "${RDS_SG_ID}" \
    --db-subnet-group-name "${DB_SUBNET_GROUP_NAME}" \
    --db-parameter-group-name "${DB_PARAMETER_GROUP_NAME}" \
    "${RDS_MULTI_AZ_FLAG}" \
    --no-publicly-accessible \
    --backup-retention-period "${RDS_BACKUP_RETENTION_DAYS}" \
    --storage-type "${RDS_STORAGE_TYPE}" \
    --no-deletion-protection \
    --region "${REGION}" >/dev/null
fi

aws rds wait db-instance-available --db-instance-identifier "${RDS_INSTANCE_IDENTIFIER}" --region "${REGION}"

RDS_INSTANCE_INFO="$(aws rds describe-db-instances \
  --db-instance-identifier "${RDS_INSTANCE_IDENTIFIER}" \
  --output json)"
RDS_ENDPOINT="$(printf '%s' "${RDS_INSTANCE_INFO}" | jq -r '.DBInstances[0].Endpoint.Address')"
MASTER_USERNAME="$(printf '%s' "${RDS_INSTANCE_INFO}" | jq -r '.DBInstances[0].MasterUsername')"

grep -vE '^(DB_SUBNET_GROUP_NAME|DB_PARAMETER_GROUP_NAME|RDS_INSTANCE_IDENTIFIER|RDS_ENDPOINT|MASTER_USERNAME|DB_NAME|AUTHIFY_USER)=' "$VARIABLES_FILE" > "$VARIABLES_FILE.tmp" || true
{
  cat "$VARIABLES_FILE.tmp"
  echo "DB_SUBNET_GROUP_NAME=$DB_SUBNET_GROUP_NAME"
  echo "DB_PARAMETER_GROUP_NAME=$DB_PARAMETER_GROUP_NAME"
  echo "RDS_INSTANCE_IDENTIFIER=$RDS_INSTANCE_IDENTIFIER"
  echo "RDS_ENDPOINT=$RDS_ENDPOINT"
  echo "MASTER_USERNAME=$MASTER_USERNAME"
  echo "DB_NAME=$DB_NAME"
  echo "AUTHIFY_USER=$AUTHIFY_USER"
} > "$VARIABLES_FILE"
rm -f "$VARIABLES_FILE.tmp"

echo "✅ RDS ready: $RDS_ENDPOINT (multi-az=${RDS_MULTI_AZ})"
