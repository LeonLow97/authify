#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
    echo "Missing $var_name. Set it in $ROOT_DIR/.env before running deploy.sh."
    exit 1
  fi
}

require_non_empty MASTER_PASSWORD
require_non_empty AUTHIFY_USER_PASSWORD
require_non_empty AUTH_JWT_TOKEN_SECRET

VPC_SCRIPT="${ROOT_DIR}/vpc/deploy.sh"
IAM_SCRIPT="${ROOT_DIR}/iam/deploy.sh"
S3_SCHEMA_SCRIPT="${ROOT_DIR}/s3/schema/deploy.sh"
EC2_KEYS_SCRIPT="${ROOT_DIR}/ec2/keys/deploy.sh"
SG_SCRIPT="${ROOT_DIR}/security-group/deploy.sh"
RDS_SCRIPT="${ROOT_DIR}/rds/deploy.sh"
ECR_SCRIPT="${ROOT_DIR}/ecr/deploy.sh"
ELASTICACHE_SCRIPT="${ROOT_DIR}/elasticache/deploy.sh"
SSM_SCRIPT="${ROOT_DIR}/ssm/deploy.sh"
EC2_USER_SERVICE_SCRIPT="${ROOT_DIR}/ec2/user-service/deploy.sh"
EC2_API_GATEWAY_SCRIPT="${ROOT_DIR}/ec2/api-gateway/deploy.sh"
S3_PEM_SCRIPT="${ROOT_DIR}/s3/pem/deploy.sh"
EC2_BASTION_SCRIPT="${ROOT_DIR}/ec2/bastion/deploy.sh"
ALB_SCRIPT="${ROOT_DIR}/alb/deploy.sh"

"$VPC_SCRIPT"
"$IAM_SCRIPT"
"$S3_SCHEMA_SCRIPT"
"$ECR_SCRIPT"
"$SG_SCRIPT"
"$RDS_SCRIPT"
"$ELASTICACHE_SCRIPT"
"$SSM_SCRIPT"
"$EC2_KEYS_SCRIPT"
"$S3_PEM_SCRIPT"
"$EC2_BASTION_SCRIPT"
"$EC2_USER_SERVICE_SCRIPT"
"$EC2_API_GATEWAY_SCRIPT"
"$ALB_SCRIPT"

echo "🎉 Infrastructure provisioning completed successfully"
