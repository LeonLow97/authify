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

if [[ -z "${VPC_ID:-}" ]]; then
  echo "Missing VPC_ID. Run vpc/deploy.sh first."
  exit 1
fi

PUBLIC_IP="$(curl -sS https://checkip.amazonaws.com | tr -d '[:space:]')"

if aws ec2 describe-security-groups --group-ids "${BASTION_SG_ID:-missing}" --region "${REGION}" >/dev/null 2>&1; then
  echo "Bastion security group already exists, skipping creation."
else
  BASTION_SG_ID="$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=${BASTION_SG_NAME}" "Name=vpc-id,Values=${VPC_ID}" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || true)"
  [[ "$BASTION_SG_ID" == "None" || "$BASTION_SG_ID" == "null" ]] && BASTION_SG_ID=""
  if [[ -z "$BASTION_SG_ID" ]]; then
    BASTION_SG_ID="$(aws ec2 create-security-group \
      --group-name "${BASTION_SG_NAME}" \
      --description "Security group for Bastion hosts" \
      --vpc-id "${VPC_ID}" \
      --region "${REGION}" \
      --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=${BASTION_SG_NAME}}]" \
      --query 'GroupId' \
      --output text)"
  fi
fi

if aws ec2 describe-security-groups --group-ids "${ALB_SG_ID:-missing}" --region "${REGION}" >/dev/null 2>&1; then
  echo "ALB security group already exists, skipping creation."
else
  ALB_SG_ID="$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=${ALB_SG_NAME}" "Name=vpc-id,Values=${VPC_ID}" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || true)"
  [[ "$ALB_SG_ID" == "None" || "$ALB_SG_ID" == "null" ]] && ALB_SG_ID=""
  if [[ -z "$ALB_SG_ID" ]]; then
    ALB_SG_ID="$(aws ec2 create-security-group \
      --group-name "${ALB_SG_NAME}" \
      --description "Security group for Authify ALB" \
      --vpc-id "${VPC_ID}" \
      --region "${REGION}" \
      --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=${ALB_SG_NAME}}]" \
      --query 'GroupId' \
      --output text)"
  fi
fi

if aws ec2 describe-security-groups --group-ids "${API_GATEWAY_SG_ID:-missing}" --region "${REGION}" >/dev/null 2>&1; then
  echo "API Gateway security group already exists, skipping creation."
else
  API_GATEWAY_SG_ID="$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=${API_GATEWAY_SG_NAME}" "Name=vpc-id,Values=${VPC_ID}" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || true)"
  [[ "$API_GATEWAY_SG_ID" == "None" || "$API_GATEWAY_SG_ID" == "null" ]] && API_GATEWAY_SG_ID=""
  if [[ -z "$API_GATEWAY_SG_ID" ]]; then
    API_GATEWAY_SG_ID="$(aws ec2 create-security-group \
      --group-name "${API_GATEWAY_SG_NAME}" \
      --description "Security group for Authify API Gateway" \
      --vpc-id "${VPC_ID}" \
      --region "${REGION}" \
      --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=${API_GATEWAY_SG_NAME}}]" \
      --query 'GroupId' \
      --output text)"
  fi
fi

if aws ec2 describe-security-groups --group-ids "${USER_SERVICE_SG_ID:-missing}" --region "${REGION}" >/dev/null 2>&1; then
  echo "User Service security group already exists, skipping creation."
else
  USER_SERVICE_SG_ID="$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=${USER_SERVICE_SG_NAME}" "Name=vpc-id,Values=${VPC_ID}" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || true)"
  [[ "$USER_SERVICE_SG_ID" == "None" || "$USER_SERVICE_SG_ID" == "null" ]] && USER_SERVICE_SG_ID=""
  if [[ -z "$USER_SERVICE_SG_ID" ]]; then
    USER_SERVICE_SG_ID="$(aws ec2 create-security-group \
      --group-name "${USER_SERVICE_SG_NAME}" \
      --description "Security group for Authify User Service" \
      --vpc-id "${VPC_ID}" \
      --region "${REGION}" \
      --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=${USER_SERVICE_SG_NAME}}]" \
      --query 'GroupId' \
      --output text)"
  fi
fi

if aws ec2 describe-security-groups --group-ids "${RDS_SG_ID:-missing}" --region "${REGION}" >/dev/null 2>&1; then
  echo "RDS security group already exists, skipping creation."
else
  RDS_SG_ID="$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=${RDS_SG_NAME}" "Name=vpc-id,Values=${VPC_ID}" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || true)"
  [[ "$RDS_SG_ID" == "None" || "$RDS_SG_ID" == "null" ]] && RDS_SG_ID=""
  if [[ -z "$RDS_SG_ID" ]]; then
    RDS_SG_ID="$(aws ec2 create-security-group \
      --group-name "${RDS_SG_NAME}" \
      --description "Security group for Authify RDS" \
      --vpc-id "${VPC_ID}" \
      --region "${REGION}" \
      --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=${RDS_SG_NAME}}]" \
      --query 'GroupId' \
      --output text)"
  fi
fi

if aws ec2 describe-security-groups --group-ids "${ELASTICACHE_SG_ID:-missing}" --region "${REGION}" >/dev/null 2>&1; then
  echo "ElastiCache security group already exists, skipping creation."
else
  ELASTICACHE_SG_ID="$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=${ELASTICACHE_SG_NAME}" "Name=vpc-id,Values=${VPC_ID}" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || true)"
  [[ "$ELASTICACHE_SG_ID" == "None" || "$ELASTICACHE_SG_ID" == "null" ]] && ELASTICACHE_SG_ID=""
  if [[ -z "$ELASTICACHE_SG_ID" ]]; then
    ELASTICACHE_SG_ID="$(aws ec2 create-security-group \
      --group-name "${ELASTICACHE_SG_NAME}" \
      --description "Security group for Authify ElastiCache" \
      --vpc-id "${VPC_ID}" \
      --region "${REGION}" \
      --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=${ELASTICACHE_SG_NAME}}]" \
      --query 'GroupId' \
      --output text)"
  fi
fi

aws ec2 authorize-security-group-ingress \
  --group-id "${BASTION_SG_ID}" \
  --protocol tcp \
  --port 22 \
  --cidr "${PUBLIC_IP}/32" >/dev/null 2>&1 || true

aws ec2 authorize-security-group-ingress \
  --group-id "${ALB_SG_ID}" \
  --ip-permissions '[
    {"IpProtocol":"tcp","FromPort":80,"ToPort":80,"IpRanges":[{"CidrIp":"0.0.0.0/0"}]},
    {"IpProtocol":"tcp","FromPort":443,"ToPort":443,"IpRanges":[{"CidrIp":"0.0.0.0/0"}]}
  ]' >/dev/null 2>&1 || true

aws ec2 authorize-security-group-ingress \
  --group-id "${API_GATEWAY_SG_ID}" \
  --ip-permissions "[
    {\"IpProtocol\":\"tcp\",\"FromPort\":${PORT_API_GATEWAY},\"ToPort\":${PORT_API_GATEWAY},\"UserIdGroupPairs\":[{\"GroupId\":\"${ALB_SG_ID}\"}]},
    {\"IpProtocol\":\"tcp\",\"FromPort\":22,\"ToPort\":22,\"UserIdGroupPairs\":[{\"GroupId\":\"${BASTION_SG_ID}\"}]},
    {\"IpProtocol\":\"tcp\",\"FromPort\":${PORT_API_GATEWAY},\"ToPort\":${PORT_API_GATEWAY},\"UserIdGroupPairs\":[{\"GroupId\":\"${BASTION_SG_ID}\"}]}
  ]" >/dev/null 2>&1 || true

aws ec2 authorize-security-group-ingress \
  --group-id "${USER_SERVICE_SG_ID}" \
  --ip-permissions "[
    {\"IpProtocol\":\"tcp\",\"FromPort\":22,\"ToPort\":22,\"UserIdGroupPairs\":[{\"GroupId\":\"${BASTION_SG_ID}\"}]},
    {\"IpProtocol\":\"tcp\",\"FromPort\":${PORT_USER_SERVICE},\"ToPort\":${PORT_USER_SERVICE},\"UserIdGroupPairs\":[{\"GroupId\":\"${API_GATEWAY_SG_ID}\"}]},
    {\"IpProtocol\":\"tcp\",\"FromPort\":${PORT_USER_SERVICE},\"ToPort\":${PORT_USER_SERVICE},\"UserIdGroupPairs\":[{\"GroupId\":\"${BASTION_SG_ID}\"}]}
  ]" >/dev/null 2>&1 || true

aws ec2 authorize-security-group-ingress \
  --group-id "${RDS_SG_ID}" \
  --ip-permissions "[
    {\"IpProtocol\":\"tcp\",\"FromPort\":${PORT_POSTGRESQL},\"ToPort\":${PORT_POSTGRESQL},\"UserIdGroupPairs\":[{\"GroupId\":\"${USER_SERVICE_SG_ID}\"}]},
    {\"IpProtocol\":\"tcp\",\"FromPort\":${PORT_POSTGRESQL},\"ToPort\":${PORT_POSTGRESQL},\"UserIdGroupPairs\":[{\"GroupId\":\"${BASTION_SG_ID}\"}]}
  ]" >/dev/null 2>&1 || true

aws ec2 authorize-security-group-ingress \
  --group-id "${ELASTICACHE_SG_ID}" \
  --ip-permissions '[
    {"IpProtocol":"tcp","FromPort":6379,"ToPort":6379,"UserIdGroupPairs":[{"GroupId":"'"${USER_SERVICE_SG_ID}"'"}]},
    {"IpProtocol":"tcp","FromPort":6379,"ToPort":6379,"UserIdGroupPairs":[{"GroupId":"'"${API_GATEWAY_SG_ID}"'"}]},
    {"IpProtocol":"tcp","FromPort":6379,"ToPort":6379,"UserIdGroupPairs":[{"GroupId":"'"${BASTION_SG_ID}"'"}]}
  ]' >/dev/null 2>&1 || true

grep -vE '^(PUBLIC_IP|BASTION_SG_ID|ALB_SG_ID|API_GATEWAY_SG_ID|USER_SERVICE_SG_ID|RDS_SG_ID|ELASTICACHE_SG_ID)=' "$VARIABLES_FILE" > "$VARIABLES_FILE.tmp" || true
{
  cat "$VARIABLES_FILE.tmp"
  echo "PUBLIC_IP=$PUBLIC_IP"
  echo "BASTION_SG_ID=$BASTION_SG_ID"
  echo "ALB_SG_ID=$ALB_SG_ID"
  echo "API_GATEWAY_SG_ID=$API_GATEWAY_SG_ID"
  echo "USER_SERVICE_SG_ID=$USER_SERVICE_SG_ID"
  echo "RDS_SG_ID=$RDS_SG_ID"
  echo "ELASTICACHE_SG_ID=$ELASTICACHE_SG_ID"
} > "$VARIABLES_FILE"
rm -f "$VARIABLES_FILE.tmp"

echo "✅ Security groups ready."
