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
CONFIG_DOCKER_AUTHIFY_USER_SERVICE_IMAGE_TAG="${DOCKER_AUTHIFY_USER_SERVICE_IMAGE_TAG}"
VARIABLES_FILE="${VARIABLES_FILE:-variables.env}"
if [[ "$VARIABLES_FILE" != /* ]]; then
  VARIABLES_FILE="$ROOT_DIR/$VARIABLES_FILE"
fi
touch "$VARIABLES_FILE"
source "$VARIABLES_FILE"
set +a

ECR_AUTHIFY_REPOSITORY="${CONFIG_ECR_AUTHIFY_REPOSITORY}"
DOCKER_AUTHIFY_USER_SERVICE_IMAGE_TAG="${CONFIG_DOCKER_AUTHIFY_USER_SERVICE_IMAGE_TAG}"

if [[ -z "${USER_SERVICE_SG_ID:-}" || -z "${PRIVATE_SUBNET_AZ1_ID:-}" || -z "${PRIVATE_SUBNET_AZ2_ID:-}" ]]; then
  echo "Missing user-service security group or private subnet values. Run the earlier deploy steps first."
  exit 1
fi

if aws ec2 describe-key-pairs --key-names "$EC2_USER_SERVICE_KEY_NAME_AZ1" >/dev/null 2>&1; then
  [[ -f "$ROOT_DIR/${EC2_USER_SERVICE_KEY_NAME_AZ1}.pem" ]] || { echo "Missing $ROOT_DIR/${EC2_USER_SERVICE_KEY_NAME_AZ1}.pem"; exit 1; }
else
  echo "Creating key pair $EC2_USER_SERVICE_KEY_NAME_AZ1 ..."
  aws ec2 create-key-pair --key-name "$EC2_USER_SERVICE_KEY_NAME_AZ1" --query 'KeyMaterial' --output text > "$ROOT_DIR/${EC2_USER_SERVICE_KEY_NAME_AZ1}.pem"
fi
chmod 400 "$ROOT_DIR/${EC2_USER_SERVICE_KEY_NAME_AZ1}.pem"

if aws ec2 describe-key-pairs --key-names "$EC2_USER_SERVICE_KEY_NAME_AZ2" >/dev/null 2>&1; then
  [[ -f "$ROOT_DIR/${EC2_USER_SERVICE_KEY_NAME_AZ2}.pem" ]] || { echo "Missing $ROOT_DIR/${EC2_USER_SERVICE_KEY_NAME_AZ2}.pem"; exit 1; }
else
  echo "Creating key pair $EC2_USER_SERVICE_KEY_NAME_AZ2 ..."
  aws ec2 create-key-pair --key-name "$EC2_USER_SERVICE_KEY_NAME_AZ2" --query 'KeyMaterial' --output text > "$ROOT_DIR/${EC2_USER_SERVICE_KEY_NAME_AZ2}.pem"
fi
chmod 400 "$ROOT_DIR/${EC2_USER_SERVICE_KEY_NAME_AZ2}.pem"

AZ1_USERDATA="/tmp/authify-user-service-az1.sh"
AZ2_USERDATA="/tmp/authify-user-service-az2.sh"
envsubst '${ECR_AUTHIFY_REPOSITORY} ${DOCKER_AUTHIFY_USER_SERVICE_IMAGE_TAG} ${PORT_USER_SERVICE} ${PORT_POSTGRESQL}' \
  < "$ROOT_DIR/ec2/user-data-scripts/user-service.sh.template" > "$AZ1_USERDATA"
envsubst '${ECR_AUTHIFY_REPOSITORY} ${DOCKER_AUTHIFY_USER_SERVICE_IMAGE_TAG} ${PORT_USER_SERVICE} ${PORT_POSTGRESQL}' \
  < "$ROOT_DIR/ec2/user-data-scripts/user-service.sh.template" > "$AZ2_USERDATA"

if ! aws ec2 describe-instances --instance-ids "${USER_SERVICE_INSTANCE_ID_AZ1:-missing}" >/dev/null 2>&1; then
  USER_SERVICE_INSTANCE_ID_AZ1="$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${USER_SERVICE_INSTANCE_NAME_AZ1}" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text 2>/dev/null || true)"
  [[ "$USER_SERVICE_INSTANCE_ID_AZ1" == "None" || "$USER_SERVICE_INSTANCE_ID_AZ1" == "null" ]] && USER_SERVICE_INSTANCE_ID_AZ1=""
fi

if [[ -z "${USER_SERVICE_INSTANCE_ID_AZ1:-}" ]]; then
  echo "Launching user-service instance in $AZ1 ..."
  if [[ "${EC2_PURCHASE_OPTION}" == "spot" ]]; then
    USER_SERVICE_INSTANCE_ID_AZ1="$(aws ec2 run-instances \
      --image-id "$EC2_AMI_ID" \
      --count 1 \
      --instance-type "$USER_SERVICE_INSTANCE_TYPE" \
      --key-name "$EC2_USER_SERVICE_KEY_NAME_AZ1" \
      --security-group-ids "$USER_SERVICE_SG_ID" \
      --subnet-id "$PRIVATE_SUBNET_AZ1_ID" \
      --iam-instance-profile "Name=${EC2_INSTANCE_PROFILE_NAME}" \
      --user-data "file://$AZ1_USERDATA" \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${USER_SERVICE_INSTANCE_NAME_AZ1}}]" \
      --instance-market-options "MarketType=spot,SpotOptions={InstanceInterruptionBehavior=terminate}" \
      --query 'Instances[0].InstanceId' \
      --output text)"
  else
    USER_SERVICE_INSTANCE_ID_AZ1="$(aws ec2 run-instances \
      --image-id "$EC2_AMI_ID" \
      --count 1 \
      --instance-type "$USER_SERVICE_INSTANCE_TYPE" \
      --key-name "$EC2_USER_SERVICE_KEY_NAME_AZ1" \
      --security-group-ids "$USER_SERVICE_SG_ID" \
      --subnet-id "$PRIVATE_SUBNET_AZ1_ID" \
      --iam-instance-profile "Name=${EC2_INSTANCE_PROFILE_NAME}" \
      --user-data "file://$AZ1_USERDATA" \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${USER_SERVICE_INSTANCE_NAME_AZ1}}]" \
      --query 'Instances[0].InstanceId' \
      --output text)"
  fi
else
  echo "User-service instance $USER_SERVICE_INSTANCE_NAME_AZ1 already exists, skipping creation."
fi

if ! aws ec2 describe-instances --instance-ids "${USER_SERVICE_INSTANCE_ID_AZ2:-missing}" >/dev/null 2>&1; then
  USER_SERVICE_INSTANCE_ID_AZ2="$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${USER_SERVICE_INSTANCE_NAME_AZ2}" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text 2>/dev/null || true)"
  [[ "$USER_SERVICE_INSTANCE_ID_AZ2" == "None" || "$USER_SERVICE_INSTANCE_ID_AZ2" == "null" ]] && USER_SERVICE_INSTANCE_ID_AZ2=""
fi

if [[ -z "${USER_SERVICE_INSTANCE_ID_AZ2:-}" ]]; then
  echo "Launching user-service instance in $AZ2 ..."
  if [[ "${EC2_PURCHASE_OPTION}" == "spot" ]]; then
    USER_SERVICE_INSTANCE_ID_AZ2="$(aws ec2 run-instances \
      --image-id "$EC2_AMI_ID" \
      --count 1 \
      --instance-type "$USER_SERVICE_INSTANCE_TYPE" \
      --key-name "$EC2_USER_SERVICE_KEY_NAME_AZ2" \
      --security-group-ids "$USER_SERVICE_SG_ID" \
      --subnet-id "$PRIVATE_SUBNET_AZ2_ID" \
      --iam-instance-profile "Name=${EC2_INSTANCE_PROFILE_NAME}" \
      --user-data "file://$AZ2_USERDATA" \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${USER_SERVICE_INSTANCE_NAME_AZ2}}]" \
      --instance-market-options "MarketType=spot,SpotOptions={InstanceInterruptionBehavior=terminate}" \
      --query 'Instances[0].InstanceId' \
      --output text)"
  else
    USER_SERVICE_INSTANCE_ID_AZ2="$(aws ec2 run-instances \
      --image-id "$EC2_AMI_ID" \
      --count 1 \
      --instance-type "$USER_SERVICE_INSTANCE_TYPE" \
      --key-name "$EC2_USER_SERVICE_KEY_NAME_AZ2" \
      --security-group-ids "$USER_SERVICE_SG_ID" \
      --subnet-id "$PRIVATE_SUBNET_AZ2_ID" \
      --iam-instance-profile "Name=${EC2_INSTANCE_PROFILE_NAME}" \
      --user-data "file://$AZ2_USERDATA" \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${USER_SERVICE_INSTANCE_NAME_AZ2}}]" \
      --query 'Instances[0].InstanceId' \
      --output text)"
  fi
else
  echo "User-service instance $USER_SERVICE_INSTANCE_NAME_AZ2 already exists, skipping creation."
fi

aws ec2 wait instance-running --instance-ids "$USER_SERVICE_INSTANCE_ID_AZ1" "$USER_SERVICE_INSTANCE_ID_AZ2"
aws ec2 wait instance-status-ok --instance-ids "$USER_SERVICE_INSTANCE_ID_AZ1" "$USER_SERVICE_INSTANCE_ID_AZ2"

USER_SERVICE_PRIVATE_IP_AZ1="$(aws ec2 describe-instances --instance-ids "$USER_SERVICE_INSTANCE_ID_AZ1" --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)"
USER_SERVICE_PRIVATE_IP_AZ2="$(aws ec2 describe-instances --instance-ids "$USER_SERVICE_INSTANCE_ID_AZ2" --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)"

grep -vE '^(USER_SERVICE_INSTANCE_ID_AZ1|USER_SERVICE_INSTANCE_ID_AZ2|USER_SERVICE_PRIVATE_IP_AZ1|USER_SERVICE_PRIVATE_IP_AZ2)=' "$VARIABLES_FILE" > "$VARIABLES_FILE.tmp" || true
{
  cat "$VARIABLES_FILE.tmp"
  echo "USER_SERVICE_INSTANCE_ID_AZ1=$USER_SERVICE_INSTANCE_ID_AZ1"
  echo "USER_SERVICE_INSTANCE_ID_AZ2=$USER_SERVICE_INSTANCE_ID_AZ2"
  echo "USER_SERVICE_PRIVATE_IP_AZ1=$USER_SERVICE_PRIVATE_IP_AZ1"
  echo "USER_SERVICE_PRIVATE_IP_AZ2=$USER_SERVICE_PRIVATE_IP_AZ2"
} > "$VARIABLES_FILE"
rm -f "$VARIABLES_FILE.tmp"
rm -f "$AZ1_USERDATA" "$AZ2_USERDATA"

echo "✅ User Service instances ready."
