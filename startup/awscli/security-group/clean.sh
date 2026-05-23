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

if [[ -n "${VPC_ID:-}" ]]; then
  if ! aws ec2 describe-security-groups --group-ids "${ELASTICACHE_SG_ID:-missing}" --region "${REGION}" >/dev/null 2>&1; then
    ELASTICACHE_SG_ID="$(aws ec2 describe-security-groups --filters "Name=group-name,Values=${ELASTICACHE_SG_NAME}" "Name=vpc-id,Values=${VPC_ID}" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)"
    [[ "$ELASTICACHE_SG_ID" == "None" || "$ELASTICACHE_SG_ID" == "null" ]] && ELASTICACHE_SG_ID=""
  fi
  if ! aws ec2 describe-security-groups --group-ids "${RDS_SG_ID:-missing}" --region "${REGION}" >/dev/null 2>&1; then
    RDS_SG_ID="$(aws ec2 describe-security-groups --filters "Name=group-name,Values=${RDS_SG_NAME}" "Name=vpc-id,Values=${VPC_ID}" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)"
    [[ "$RDS_SG_ID" == "None" || "$RDS_SG_ID" == "null" ]] && RDS_SG_ID=""
  fi
  if ! aws ec2 describe-security-groups --group-ids "${USER_SERVICE_SG_ID:-missing}" --region "${REGION}" >/dev/null 2>&1; then
    USER_SERVICE_SG_ID="$(aws ec2 describe-security-groups --filters "Name=group-name,Values=${USER_SERVICE_SG_NAME}" "Name=vpc-id,Values=${VPC_ID}" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)"
    [[ "$USER_SERVICE_SG_ID" == "None" || "$USER_SERVICE_SG_ID" == "null" ]] && USER_SERVICE_SG_ID=""
  fi
  if ! aws ec2 describe-security-groups --group-ids "${API_GATEWAY_SG_ID:-missing}" --region "${REGION}" >/dev/null 2>&1; then
    API_GATEWAY_SG_ID="$(aws ec2 describe-security-groups --filters "Name=group-name,Values=${API_GATEWAY_SG_NAME}" "Name=vpc-id,Values=${VPC_ID}" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)"
    [[ "$API_GATEWAY_SG_ID" == "None" || "$API_GATEWAY_SG_ID" == "null" ]] && API_GATEWAY_SG_ID=""
  fi
  if ! aws ec2 describe-security-groups --group-ids "${BASTION_SG_ID:-missing}" --region "${REGION}" >/dev/null 2>&1; then
    BASTION_SG_ID="$(aws ec2 describe-security-groups --filters "Name=group-name,Values=${BASTION_SG_NAME}" "Name=vpc-id,Values=${VPC_ID}" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)"
    [[ "$BASTION_SG_ID" == "None" || "$BASTION_SG_ID" == "null" ]] && BASTION_SG_ID=""
  fi
  if ! aws ec2 describe-security-groups --group-ids "${ALB_SG_ID:-missing}" --region "${REGION}" >/dev/null 2>&1; then
    ALB_SG_ID="$(aws ec2 describe-security-groups --filters "Name=group-name,Values=${ALB_SG_NAME}" "Name=vpc-id,Values=${VPC_ID}" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)"
    [[ "$ALB_SG_ID" == "None" || "$ALB_SG_ID" == "null" ]] && ALB_SG_ID=""
  fi
fi

groups=(
  "${ELASTICACHE_SG_ID:-}"
  "${RDS_SG_ID:-}"
  "${USER_SERVICE_SG_ID:-}"
  "${API_GATEWAY_SG_ID:-}"
  "${BASTION_SG_ID:-}"
  "${ALB_SG_ID:-}"
)

for _ in $(seq 1 6); do
  pending=0
  progress=0

  for sg_id in "${groups[@]}"; do
    if [[ -z "${sg_id}" ]]; then
      continue
    fi
    if aws ec2 describe-security-groups --group-ids "${sg_id}" --region "${REGION}" >/dev/null 2>&1; then
      pending=1
      if aws ec2 delete-security-group --group-id "${sg_id}" --region "${REGION}" >/dev/null 2>&1; then
        progress=1
      fi
    fi
  done

  if [[ "${pending}" -eq 0 ]]; then
    break
  fi

  if [[ "${progress}" -eq 0 ]]; then
    sleep 5
  fi
done

for sg_id in "${groups[@]}"; do
  [[ -n "${sg_id}" ]] || continue
  if aws ec2 describe-security-groups --group-ids "${sg_id}" --region "${REGION}" >/dev/null 2>&1; then
    echo "Security group ${sg_id} still exists after cleanup."
    exit 1
  fi
done

grep -vE '^(PUBLIC_IP|BASTION_SG_ID|ALB_SG_ID|API_GATEWAY_SG_ID|USER_SERVICE_SG_ID|RDS_SG_ID|ELASTICACHE_SG_ID)=' "$VARIABLES_FILE" > "$VARIABLES_FILE.tmp" || true
mv "$VARIABLES_FILE.tmp" "$VARIABLES_FILE"

echo "✅ Security group cleanup completed."
