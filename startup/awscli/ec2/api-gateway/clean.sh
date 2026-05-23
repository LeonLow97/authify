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

if ! aws ec2 describe-instances --instance-ids "${API_GATEWAY_INSTANCE_ID_AZ1:-missing}" >/dev/null 2>&1; then
  API_GATEWAY_INSTANCE_ID_AZ1="$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${API_GATEWAY_INSTANCE_NAME_AZ1}" "Name=instance-state-name,Values=pending,running,stopping,stopped" --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null || true)"
  [[ "$API_GATEWAY_INSTANCE_ID_AZ1" == "None" || "$API_GATEWAY_INSTANCE_ID_AZ1" == "null" ]] && API_GATEWAY_INSTANCE_ID_AZ1=""
fi

if ! aws ec2 describe-instances --instance-ids "${API_GATEWAY_INSTANCE_ID_AZ2:-missing}" >/dev/null 2>&1; then
  API_GATEWAY_INSTANCE_ID_AZ2="$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${API_GATEWAY_INSTANCE_NAME_AZ2}" "Name=instance-state-name,Values=pending,running,stopping,stopped" --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null || true)"
  [[ "$API_GATEWAY_INSTANCE_ID_AZ2" == "None" || "$API_GATEWAY_INSTANCE_ID_AZ2" == "null" ]] && API_GATEWAY_INSTANCE_ID_AZ2=""
fi

if [[ -n "${API_GATEWAY_INSTANCE_ID_AZ1:-}" ]]; then
  aws ec2 terminate-instances --instance-ids "$API_GATEWAY_INSTANCE_ID_AZ1" >/dev/null 2>&1 || true
  aws ec2 wait instance-terminated --instance-ids "$API_GATEWAY_INSTANCE_ID_AZ1" >/dev/null 2>&1 || true
fi

if [[ -n "${API_GATEWAY_INSTANCE_ID_AZ2:-}" ]]; then
  aws ec2 terminate-instances --instance-ids "$API_GATEWAY_INSTANCE_ID_AZ2" >/dev/null 2>&1 || true
  aws ec2 wait instance-terminated --instance-ids "$API_GATEWAY_INSTANCE_ID_AZ2" >/dev/null 2>&1 || true
fi

aws ec2 delete-key-pair --key-name "${EC2_API_GATEWAY_KEY_NAME_AZ1}" >/dev/null 2>&1 || true
aws ec2 delete-key-pair --key-name "${EC2_API_GATEWAY_KEY_NAME_AZ2}" >/dev/null 2>&1 || true
rm -f "$ROOT_DIR/${EC2_API_GATEWAY_KEY_NAME_AZ1}.pem" "$ROOT_DIR/${EC2_API_GATEWAY_KEY_NAME_AZ2}.pem"

grep -vE '^(API_GATEWAY_INSTANCE_ID_AZ1|API_GATEWAY_INSTANCE_ID_AZ2|API_GATEWAY_PRIVATE_IP_AZ1|API_GATEWAY_PRIVATE_IP_AZ2)=' "$VARIABLES_FILE" > "$VARIABLES_FILE.tmp" || true
mv "$VARIABLES_FILE.tmp" "$VARIABLES_FILE"

echo "✅ API Gateway cleanup completed."
