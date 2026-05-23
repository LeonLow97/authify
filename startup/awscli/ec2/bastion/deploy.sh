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

if [[ -z "${BASTION_SG_ID:-}" || -z "${PUBLIC_SUBNET_AZ1_ID:-}" || -z "${PUBLIC_SUBNET_AZ2_ID:-}" ]]; then
  echo "Missing bastion security group or public subnet values. Run the earlier deploy steps first."
  exit 1
fi

if aws ec2 describe-key-pairs --key-names "$EC2_BASTION_HOST_KEY_NAME_AZ1" >/dev/null 2>&1; then
  [[ -f "$ROOT_DIR/${EC2_BASTION_HOST_KEY_NAME_AZ1}.pem" ]] || { echo "Missing $ROOT_DIR/${EC2_BASTION_HOST_KEY_NAME_AZ1}.pem"; exit 1; }
else
  echo "Creating key pair $EC2_BASTION_HOST_KEY_NAME_AZ1 ..."
  aws ec2 create-key-pair --key-name "$EC2_BASTION_HOST_KEY_NAME_AZ1" --query 'KeyMaterial' --output text > "$ROOT_DIR/${EC2_BASTION_HOST_KEY_NAME_AZ1}.pem"
fi
chmod 400 "$ROOT_DIR/${EC2_BASTION_HOST_KEY_NAME_AZ1}.pem"

if aws ec2 describe-key-pairs --key-names "$EC2_BASTION_HOST_KEY_NAME_AZ2" >/dev/null 2>&1; then
  [[ -f "$ROOT_DIR/${EC2_BASTION_HOST_KEY_NAME_AZ2}.pem" ]] || { echo "Missing $ROOT_DIR/${EC2_BASTION_HOST_KEY_NAME_AZ2}.pem"; exit 1; }
else
  echo "Creating key pair $EC2_BASTION_HOST_KEY_NAME_AZ2 ..."
  aws ec2 create-key-pair --key-name "$EC2_BASTION_HOST_KEY_NAME_AZ2" --query 'KeyMaterial' --output text > "$ROOT_DIR/${EC2_BASTION_HOST_KEY_NAME_AZ2}.pem"
fi
chmod 400 "$ROOT_DIR/${EC2_BASTION_HOST_KEY_NAME_AZ2}.pem"

AZ1_USERDATA="/tmp/authify-bastion-az1.sh"
AZ2_USERDATA="/tmp/authify-bastion-az2.sh"
EC2_API_GATEWAY_KEY_NAME="$EC2_API_GATEWAY_KEY_NAME_AZ1" \
EC2_USER_SERVICE_KEY_NAME="$EC2_USER_SERVICE_KEY_NAME_AZ1" \
API_GATEWAY_PRIVATE_IP="${API_GATEWAY_PRIVATE_IP_AZ1:-}" \
USER_SERVICE_PRIVATE_IP="${USER_SERVICE_PRIVATE_IP_AZ1:-}" \
BASTION_BOOTSTRAP_DB=true \
  envsubst '${AMI_EC2_DEFAULT_USER} ${EC2_API_GATEWAY_KEY_NAME} ${EC2_USER_SERVICE_KEY_NAME} ${API_GATEWAY_PRIVATE_IP} ${USER_SERVICE_PRIVATE_IP} ${BASTION_BOOTSTRAP_DB}' \
  < "$ROOT_DIR/ec2/user-data-scripts/bastion.sh.template" > "$AZ1_USERDATA"
EC2_API_GATEWAY_KEY_NAME="$EC2_API_GATEWAY_KEY_NAME_AZ2" \
EC2_USER_SERVICE_KEY_NAME="$EC2_USER_SERVICE_KEY_NAME_AZ2" \
API_GATEWAY_PRIVATE_IP="${API_GATEWAY_PRIVATE_IP_AZ2:-}" \
USER_SERVICE_PRIVATE_IP="${USER_SERVICE_PRIVATE_IP_AZ2:-}" \
BASTION_BOOTSTRAP_DB=false \
  envsubst '${AMI_EC2_DEFAULT_USER} ${EC2_API_GATEWAY_KEY_NAME} ${EC2_USER_SERVICE_KEY_NAME} ${API_GATEWAY_PRIVATE_IP} ${USER_SERVICE_PRIVATE_IP} ${BASTION_BOOTSTRAP_DB}' \
  < "$ROOT_DIR/ec2/user-data-scripts/bastion.sh.template" > "$AZ2_USERDATA"

if ! aws ec2 describe-instances --instance-ids "${BASTION_INSTANCE_ID_AZ1:-missing}" >/dev/null 2>&1; then
  BASTION_INSTANCE_ID_AZ1="$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${BASTION_INSTANCE_NAME_AZ1}" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text 2>/dev/null || true)"
  [[ "$BASTION_INSTANCE_ID_AZ1" == "None" || "$BASTION_INSTANCE_ID_AZ1" == "null" ]] && BASTION_INSTANCE_ID_AZ1=""
fi

if [[ -z "${BASTION_INSTANCE_ID_AZ1:-}" ]]; then
  echo "Launching Bastion instance in $AZ1 ..."
  if [[ "${EC2_PURCHASE_OPTION}" == "spot" ]]; then
    BASTION_INSTANCE_ID_AZ1="$(aws ec2 run-instances \
      --image-id "$EC2_AMI_ID" \
      --count 1 \
      --instance-type "$BASTION_INSTANCE_TYPE" \
      --key-name "$EC2_BASTION_HOST_KEY_NAME_AZ1" \
      --security-group-ids "$BASTION_SG_ID" \
      --subnet-id "$PUBLIC_SUBNET_AZ1_ID" \
      --associate-public-ip-address \
      --iam-instance-profile "Name=${EC2_INSTANCE_PROFILE_NAME}" \
      --user-data "file://$AZ1_USERDATA" \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${BASTION_INSTANCE_NAME_AZ1}}]" \
      --instance-market-options "MarketType=spot,SpotOptions={InstanceInterruptionBehavior=terminate}" \
      --query 'Instances[0].InstanceId' \
      --output text)"
  else
    BASTION_INSTANCE_ID_AZ1="$(aws ec2 run-instances \
      --image-id "$EC2_AMI_ID" \
      --count 1 \
      --instance-type "$BASTION_INSTANCE_TYPE" \
      --key-name "$EC2_BASTION_HOST_KEY_NAME_AZ1" \
      --security-group-ids "$BASTION_SG_ID" \
      --subnet-id "$PUBLIC_SUBNET_AZ1_ID" \
      --associate-public-ip-address \
      --iam-instance-profile "Name=${EC2_INSTANCE_PROFILE_NAME}" \
      --user-data "file://$AZ1_USERDATA" \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${BASTION_INSTANCE_NAME_AZ1}}]" \
      --query 'Instances[0].InstanceId' \
      --output text)"
  fi
else
  echo "Bastion instance $BASTION_INSTANCE_NAME_AZ1 already exists, skipping creation."
fi

if ! aws ec2 describe-instances --instance-ids "${BASTION_INSTANCE_ID_AZ2:-missing}" >/dev/null 2>&1; then
  BASTION_INSTANCE_ID_AZ2="$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${BASTION_INSTANCE_NAME_AZ2}" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text 2>/dev/null || true)"
  [[ "$BASTION_INSTANCE_ID_AZ2" == "None" || "$BASTION_INSTANCE_ID_AZ2" == "null" ]] && BASTION_INSTANCE_ID_AZ2=""
fi

if [[ -z "${BASTION_INSTANCE_ID_AZ2:-}" ]]; then
  echo "Launching Bastion instance in $AZ2 ..."
  if [[ "${EC2_PURCHASE_OPTION}" == "spot" ]]; then
    BASTION_INSTANCE_ID_AZ2="$(aws ec2 run-instances \
      --image-id "$EC2_AMI_ID" \
      --count 1 \
      --instance-type "$BASTION_INSTANCE_TYPE" \
      --key-name "$EC2_BASTION_HOST_KEY_NAME_AZ2" \
      --security-group-ids "$BASTION_SG_ID" \
      --subnet-id "$PUBLIC_SUBNET_AZ2_ID" \
      --associate-public-ip-address \
      --iam-instance-profile "Name=${EC2_INSTANCE_PROFILE_NAME}" \
      --user-data "file://$AZ2_USERDATA" \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${BASTION_INSTANCE_NAME_AZ2}}]" \
      --instance-market-options "MarketType=spot,SpotOptions={InstanceInterruptionBehavior=terminate}" \
      --query 'Instances[0].InstanceId' \
      --output text)"
  else
    BASTION_INSTANCE_ID_AZ2="$(aws ec2 run-instances \
      --image-id "$EC2_AMI_ID" \
      --count 1 \
      --instance-type "$BASTION_INSTANCE_TYPE" \
      --key-name "$EC2_BASTION_HOST_KEY_NAME_AZ2" \
      --security-group-ids "$BASTION_SG_ID" \
      --subnet-id "$PUBLIC_SUBNET_AZ2_ID" \
      --associate-public-ip-address \
      --iam-instance-profile "Name=${EC2_INSTANCE_PROFILE_NAME}" \
      --user-data "file://$AZ2_USERDATA" \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${BASTION_INSTANCE_NAME_AZ2}}]" \
      --query 'Instances[0].InstanceId' \
      --output text)"
  fi
else
  echo "Bastion instance $BASTION_INSTANCE_NAME_AZ2 already exists, skipping creation."
fi

aws ec2 wait instance-running --instance-ids "$BASTION_INSTANCE_ID_AZ1" "$BASTION_INSTANCE_ID_AZ2"
aws ec2 wait instance-status-ok --instance-ids "$BASTION_INSTANCE_ID_AZ1" "$BASTION_INSTANCE_ID_AZ2"

BASTION_PUBLIC_IP_AZ1="$(aws ec2 describe-instances --instance-ids "$BASTION_INSTANCE_ID_AZ1" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)"
BASTION_PUBLIC_IP_AZ2="$(aws ec2 describe-instances --instance-ids "$BASTION_INSTANCE_ID_AZ2" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)"

grep -vE '^(BASTION_INSTANCE_ID_AZ1|BASTION_INSTANCE_ID_AZ2|BASTION_PUBLIC_IP_AZ1|BASTION_PUBLIC_IP_AZ2)=' "$VARIABLES_FILE" > "$VARIABLES_FILE.tmp" || true
{
  cat "$VARIABLES_FILE.tmp"
  echo "BASTION_INSTANCE_ID_AZ1=$BASTION_INSTANCE_ID_AZ1"
  echo "BASTION_INSTANCE_ID_AZ2=$BASTION_INSTANCE_ID_AZ2"
  echo "BASTION_PUBLIC_IP_AZ1=$BASTION_PUBLIC_IP_AZ1"
  echo "BASTION_PUBLIC_IP_AZ2=$BASTION_PUBLIC_IP_AZ2"
} > "$VARIABLES_FILE"
rm -f "$VARIABLES_FILE.tmp"
rm -f "$AZ1_USERDATA" "$AZ2_USERDATA"

echo "✅ Bastion instances ready."
