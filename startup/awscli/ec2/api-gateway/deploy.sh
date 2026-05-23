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
CONFIG_ECR_AUTHIFY_REPOSITORY="${ECR_AUTHIFY_REPOSITORY}"
CONFIG_DOCKER_AUTHIFY_API_GATEWAY_IMAGE_TAG="${DOCKER_AUTHIFY_API_GATEWAY_IMAGE_TAG}"
VARIABLES_FILE="${VARIABLES_FILE:-variables.env}"
if [[ "$VARIABLES_FILE" != /* ]]; then
  VARIABLES_FILE="$ROOT_DIR/$VARIABLES_FILE"
fi
touch "$VARIABLES_FILE"
source "$VARIABLES_FILE"
set +a

ECR_AUTHIFY_REPOSITORY="${CONFIG_ECR_AUTHIFY_REPOSITORY}"
DOCKER_AUTHIFY_API_GATEWAY_IMAGE_TAG="${CONFIG_DOCKER_AUTHIFY_API_GATEWAY_IMAGE_TAG}"

if [[ -z "${API_GATEWAY_SG_ID:-}" || -z "${PRIVATE_SUBNET_AZ1_ID:-}" || -z "${PRIVATE_SUBNET_AZ2_ID:-}" || -z "${USER_SERVICE_PRIVATE_IP_AZ1:-}" || -z "${USER_SERVICE_PRIVATE_IP_AZ2:-}" ]]; then
  echo "Missing API Gateway security group, private subnet, or user-service IP values. Run the earlier deploy steps first."
  exit 1
fi

if aws ec2 describe-key-pairs --key-names "$EC2_API_GATEWAY_KEY_NAME_AZ1" >/dev/null 2>&1; then
  [[ -f "$ROOT_DIR/${EC2_API_GATEWAY_KEY_NAME_AZ1}.pem" ]] || { echo "Missing $ROOT_DIR/${EC2_API_GATEWAY_KEY_NAME_AZ1}.pem"; exit 1; }
else
  echo "Creating key pair $EC2_API_GATEWAY_KEY_NAME_AZ1 ..."
  aws ec2 create-key-pair --key-name "$EC2_API_GATEWAY_KEY_NAME_AZ1" --query 'KeyMaterial' --output text > "$ROOT_DIR/${EC2_API_GATEWAY_KEY_NAME_AZ1}.pem"
fi
chmod 400 "$ROOT_DIR/${EC2_API_GATEWAY_KEY_NAME_AZ1}.pem"

if aws ec2 describe-key-pairs --key-names "$EC2_API_GATEWAY_KEY_NAME_AZ2" >/dev/null 2>&1; then
  [[ -f "$ROOT_DIR/${EC2_API_GATEWAY_KEY_NAME_AZ2}.pem" ]] || { echo "Missing $ROOT_DIR/${EC2_API_GATEWAY_KEY_NAME_AZ2}.pem"; exit 1; }
else
  echo "Creating key pair $EC2_API_GATEWAY_KEY_NAME_AZ2 ..."
  aws ec2 create-key-pair --key-name "$EC2_API_GATEWAY_KEY_NAME_AZ2" --query 'KeyMaterial' --output text > "$ROOT_DIR/${EC2_API_GATEWAY_KEY_NAME_AZ2}.pem"
fi
chmod 400 "$ROOT_DIR/${EC2_API_GATEWAY_KEY_NAME_AZ2}.pem"

AZ1_USERDATA="/tmp/authify-api-gateway-az1.sh"
AZ2_USERDATA="/tmp/authify-api-gateway-az2.sh"
USER_SERVICE_BASE_URL="$USER_SERVICE_PRIVATE_IP_AZ1" USER_SERVICE_PORT="$PORT_USER_SERVICE" \
  envsubst '${ECR_AUTHIFY_REPOSITORY} ${DOCKER_AUTHIFY_API_GATEWAY_IMAGE_TAG} ${PORT_API_GATEWAY} ${USER_SERVICE_BASE_URL} ${USER_SERVICE_PORT}' \
  < "$ROOT_DIR/ec2/user-data-scripts/api-gateway.sh.template" > "$AZ1_USERDATA"
USER_SERVICE_BASE_URL="$USER_SERVICE_PRIVATE_IP_AZ2" USER_SERVICE_PORT="$PORT_USER_SERVICE" \
  envsubst '${ECR_AUTHIFY_REPOSITORY} ${DOCKER_AUTHIFY_API_GATEWAY_IMAGE_TAG} ${PORT_API_GATEWAY} ${USER_SERVICE_BASE_URL} ${USER_SERVICE_PORT}' \
  < "$ROOT_DIR/ec2/user-data-scripts/api-gateway.sh.template" > "$AZ2_USERDATA"

if ! aws ec2 describe-instances --instance-ids "${API_GATEWAY_INSTANCE_ID_AZ1:-missing}" >/dev/null 2>&1; then
  API_GATEWAY_INSTANCE_ID_AZ1="$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${API_GATEWAY_INSTANCE_NAME_AZ1}" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text 2>/dev/null || true)"
  [[ "$API_GATEWAY_INSTANCE_ID_AZ1" == "None" || "$API_GATEWAY_INSTANCE_ID_AZ1" == "null" ]] && API_GATEWAY_INSTANCE_ID_AZ1=""
fi

if [[ -z "${API_GATEWAY_INSTANCE_ID_AZ1:-}" ]]; then
  echo "Launching API Gateway instance in $AZ1 ..."
  if [[ "${EC2_PURCHASE_OPTION}" == "spot" ]]; then
    API_GATEWAY_INSTANCE_ID_AZ1="$(aws ec2 run-instances \
      --image-id "$EC2_AMI_ID" \
      --count 1 \
      --instance-type "$API_GATEWAY_INSTANCE_TYPE" \
      --key-name "$EC2_API_GATEWAY_KEY_NAME_AZ1" \
      --security-group-ids "$API_GATEWAY_SG_ID" \
      --subnet-id "$PRIVATE_SUBNET_AZ1_ID" \
      --iam-instance-profile "Name=${EC2_INSTANCE_PROFILE_NAME}" \
      --user-data "file://$AZ1_USERDATA" \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${API_GATEWAY_INSTANCE_NAME_AZ1}}]" \
      --instance-market-options "MarketType=spot,SpotOptions={InstanceInterruptionBehavior=terminate}" \
      --query 'Instances[0].InstanceId' \
      --output text)"
  else
    API_GATEWAY_INSTANCE_ID_AZ1="$(aws ec2 run-instances \
      --image-id "$EC2_AMI_ID" \
      --count 1 \
      --instance-type "$API_GATEWAY_INSTANCE_TYPE" \
      --key-name "$EC2_API_GATEWAY_KEY_NAME_AZ1" \
      --security-group-ids "$API_GATEWAY_SG_ID" \
      --subnet-id "$PRIVATE_SUBNET_AZ1_ID" \
      --iam-instance-profile "Name=${EC2_INSTANCE_PROFILE_NAME}" \
      --user-data "file://$AZ1_USERDATA" \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${API_GATEWAY_INSTANCE_NAME_AZ1}}]" \
      --query 'Instances[0].InstanceId' \
      --output text)"
  fi
else
  echo "API Gateway instance $API_GATEWAY_INSTANCE_NAME_AZ1 already exists, skipping creation."
fi

if ! aws ec2 describe-instances --instance-ids "${API_GATEWAY_INSTANCE_ID_AZ2:-missing}" >/dev/null 2>&1; then
  API_GATEWAY_INSTANCE_ID_AZ2="$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${API_GATEWAY_INSTANCE_NAME_AZ2}" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text 2>/dev/null || true)"
  [[ "$API_GATEWAY_INSTANCE_ID_AZ2" == "None" || "$API_GATEWAY_INSTANCE_ID_AZ2" == "null" ]] && API_GATEWAY_INSTANCE_ID_AZ2=""
fi

if [[ -z "${API_GATEWAY_INSTANCE_ID_AZ2:-}" ]]; then
  echo "Launching API Gateway instance in $AZ2 ..."
  if [[ "${EC2_PURCHASE_OPTION}" == "spot" ]]; then
    API_GATEWAY_INSTANCE_ID_AZ2="$(aws ec2 run-instances \
      --image-id "$EC2_AMI_ID" \
      --count 1 \
      --instance-type "$API_GATEWAY_INSTANCE_TYPE" \
      --key-name "$EC2_API_GATEWAY_KEY_NAME_AZ2" \
      --security-group-ids "$API_GATEWAY_SG_ID" \
      --subnet-id "$PRIVATE_SUBNET_AZ2_ID" \
      --iam-instance-profile "Name=${EC2_INSTANCE_PROFILE_NAME}" \
      --user-data "file://$AZ2_USERDATA" \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${API_GATEWAY_INSTANCE_NAME_AZ2}}]" \
      --instance-market-options "MarketType=spot,SpotOptions={InstanceInterruptionBehavior=terminate}" \
      --query 'Instances[0].InstanceId' \
      --output text)"
  else
    API_GATEWAY_INSTANCE_ID_AZ2="$(aws ec2 run-instances \
      --image-id "$EC2_AMI_ID" \
      --count 1 \
      --instance-type "$API_GATEWAY_INSTANCE_TYPE" \
      --key-name "$EC2_API_GATEWAY_KEY_NAME_AZ2" \
      --security-group-ids "$API_GATEWAY_SG_ID" \
      --subnet-id "$PRIVATE_SUBNET_AZ2_ID" \
      --iam-instance-profile "Name=${EC2_INSTANCE_PROFILE_NAME}" \
      --user-data "file://$AZ2_USERDATA" \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${API_GATEWAY_INSTANCE_NAME_AZ2}}]" \
      --query 'Instances[0].InstanceId' \
      --output text)"
  fi
else
  echo "API Gateway instance $API_GATEWAY_INSTANCE_NAME_AZ2 already exists, skipping creation."
fi

aws ec2 wait instance-running --instance-ids "$API_GATEWAY_INSTANCE_ID_AZ1" "$API_GATEWAY_INSTANCE_ID_AZ2"
aws ec2 wait instance-status-ok --instance-ids "$API_GATEWAY_INSTANCE_ID_AZ1" "$API_GATEWAY_INSTANCE_ID_AZ2"

API_GATEWAY_PRIVATE_IP_AZ1="$(aws ec2 describe-instances --instance-ids "$API_GATEWAY_INSTANCE_ID_AZ1" --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)"
API_GATEWAY_PRIVATE_IP_AZ2="$(aws ec2 describe-instances --instance-ids "$API_GATEWAY_INSTANCE_ID_AZ2" --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)"

grep -vE '^(API_GATEWAY_INSTANCE_ID_AZ1|API_GATEWAY_INSTANCE_ID_AZ2|API_GATEWAY_PRIVATE_IP_AZ1|API_GATEWAY_PRIVATE_IP_AZ2)=' "$VARIABLES_FILE" > "$VARIABLES_FILE.tmp" || true
{
  cat "$VARIABLES_FILE.tmp"
  echo "API_GATEWAY_INSTANCE_ID_AZ1=$API_GATEWAY_INSTANCE_ID_AZ1"
  echo "API_GATEWAY_INSTANCE_ID_AZ2=$API_GATEWAY_INSTANCE_ID_AZ2"
  echo "API_GATEWAY_PRIVATE_IP_AZ1=$API_GATEWAY_PRIVATE_IP_AZ1"
  echo "API_GATEWAY_PRIVATE_IP_AZ2=$API_GATEWAY_PRIVATE_IP_AZ2"
} > "$VARIABLES_FILE"
rm -f "$VARIABLES_FILE.tmp"
rm -f "$AZ1_USERDATA" "$AZ2_USERDATA"

echo "✅ API Gateway instances ready."
