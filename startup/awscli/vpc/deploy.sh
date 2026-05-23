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

wait_for_nat_gateway() {
  local nat_id="$1"
  while [[ "$(aws ec2 describe-nat-gateways --nat-gateway-ids "$nat_id" --query 'NatGateways[0].State' --output text 2>/dev/null || true)" != "available" ]]; do
    sleep 10
  done
  echo "✅ NAT Gateway $nat_id is now available."
}

if aws ec2 describe-vpcs --vpc-ids "${VPC_ID:-missing}" --region "$REGION" >/dev/null 2>&1; then
  echo "VPC $VPC_NAME already exists, skipping creation."
else
  VPC_ID="$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=${VPC_NAME}" \
    --query 'Vpcs[0].VpcId' \
    --output text 2>/dev/null || true)"
  [[ "$VPC_ID" == "None" || "$VPC_ID" == "null" ]] && VPC_ID=""
  if [[ -z "$VPC_ID" ]]; then
    VPC_ID="$(aws ec2 create-vpc \
      --cidr-block "$VPC_CIDR" \
      --region "$REGION" \
      --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${VPC_NAME}}]" \
      --query 'Vpc.VpcId' \
      --output text)"
    echo "✅ Created VPC with ID: $VPC_ID"
  fi
fi

aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support '{"Value":true}' >/dev/null
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames '{"Value":true}' >/dev/null

if ! aws ec2 describe-subnets --subnet-ids "${PUBLIC_SUBNET_AZ1_ID:-missing}" --region "$REGION" >/dev/null 2>&1; then
  PUBLIC_SUBNET_AZ1_ID="$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=${PUBLIC_SUBNET_AZ1_NAME}" "Name=vpc-id,Values=${VPC_ID}" \
    --query 'Subnets[0].SubnetId' \
    --output text 2>/dev/null || true)"
  [[ "$PUBLIC_SUBNET_AZ1_ID" == "None" || "$PUBLIC_SUBNET_AZ1_ID" == "null" ]] && PUBLIC_SUBNET_AZ1_ID=""
  if [[ -z "$PUBLIC_SUBNET_AZ1_ID" ]]; then
    PUBLIC_SUBNET_AZ1_ID="$(aws ec2 create-subnet \
      --vpc-id "$VPC_ID" \
      --cidr-block "$PUBLIC_SUBNET_AZ1_CIDR" \
      --availability-zone "$AZ1" \
      --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PUBLIC_SUBNET_AZ1_NAME}}]" \
      --query 'Subnet.SubnetId' \
      --output text)"
  fi
fi

if ! aws ec2 describe-subnets --subnet-ids "${PUBLIC_SUBNET_AZ2_ID:-missing}" --region "$REGION" >/dev/null 2>&1; then
  PUBLIC_SUBNET_AZ2_ID="$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=${PUBLIC_SUBNET_AZ2_NAME}" "Name=vpc-id,Values=${VPC_ID}" \
    --query 'Subnets[0].SubnetId' \
    --output text 2>/dev/null || true)"
  [[ "$PUBLIC_SUBNET_AZ2_ID" == "None" || "$PUBLIC_SUBNET_AZ2_ID" == "null" ]] && PUBLIC_SUBNET_AZ2_ID=""
  if [[ -z "$PUBLIC_SUBNET_AZ2_ID" ]]; then
    PUBLIC_SUBNET_AZ2_ID="$(aws ec2 create-subnet \
      --vpc-id "$VPC_ID" \
      --cidr-block "$PUBLIC_SUBNET_AZ2_CIDR" \
      --availability-zone "$AZ2" \
      --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PUBLIC_SUBNET_AZ2_NAME}}]" \
      --query 'Subnet.SubnetId' \
      --output text)"
  fi
fi

if ! aws ec2 describe-subnets --subnet-ids "${PRIVATE_SUBNET_AZ1_ID:-missing}" --region "$REGION" >/dev/null 2>&1; then
  PRIVATE_SUBNET_AZ1_ID="$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=${PRIVATE_SUBNET_AZ1_NAME}" "Name=vpc-id,Values=${VPC_ID}" \
    --query 'Subnets[0].SubnetId' \
    --output text 2>/dev/null || true)"
  [[ "$PRIVATE_SUBNET_AZ1_ID" == "None" || "$PRIVATE_SUBNET_AZ1_ID" == "null" ]] && PRIVATE_SUBNET_AZ1_ID=""
  if [[ -z "$PRIVATE_SUBNET_AZ1_ID" ]]; then
    PRIVATE_SUBNET_AZ1_ID="$(aws ec2 create-subnet \
      --vpc-id "$VPC_ID" \
      --cidr-block "$PRIVATE_SUBNET_AZ1_CIDR" \
      --availability-zone "$AZ1" \
      --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PRIVATE_SUBNET_AZ1_NAME}}]" \
      --query 'Subnet.SubnetId' \
      --output text)"
  fi
fi

if ! aws ec2 describe-subnets --subnet-ids "${PRIVATE_SUBNET_AZ2_ID:-missing}" --region "$REGION" >/dev/null 2>&1; then
  PRIVATE_SUBNET_AZ2_ID="$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=${PRIVATE_SUBNET_AZ2_NAME}" "Name=vpc-id,Values=${VPC_ID}" \
    --query 'Subnets[0].SubnetId' \
    --output text 2>/dev/null || true)"
  [[ "$PRIVATE_SUBNET_AZ2_ID" == "None" || "$PRIVATE_SUBNET_AZ2_ID" == "null" ]] && PRIVATE_SUBNET_AZ2_ID=""
  if [[ -z "$PRIVATE_SUBNET_AZ2_ID" ]]; then
    PRIVATE_SUBNET_AZ2_ID="$(aws ec2 create-subnet \
      --vpc-id "$VPC_ID" \
      --cidr-block "$PRIVATE_SUBNET_AZ2_CIDR" \
      --availability-zone "$AZ2" \
      --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PRIVATE_SUBNET_AZ2_NAME}}]" \
      --query 'Subnet.SubnetId' \
      --output text)"
  fi
fi

if ! aws ec2 describe-subnets --subnet-ids "${PRIVATE_RDS_SUBNET_AZ1_ID:-missing}" --region "$REGION" >/dev/null 2>&1; then
  PRIVATE_RDS_SUBNET_AZ1_ID="$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=${PRIVATE_RDS_SUBNET_AZ1_NAME}" "Name=vpc-id,Values=${VPC_ID}" \
    --query 'Subnets[0].SubnetId' \
    --output text 2>/dev/null || true)"
  [[ "$PRIVATE_RDS_SUBNET_AZ1_ID" == "None" || "$PRIVATE_RDS_SUBNET_AZ1_ID" == "null" ]] && PRIVATE_RDS_SUBNET_AZ1_ID=""
  if [[ -z "$PRIVATE_RDS_SUBNET_AZ1_ID" ]]; then
    PRIVATE_RDS_SUBNET_AZ1_ID="$(aws ec2 create-subnet \
      --vpc-id "$VPC_ID" \
      --cidr-block "$PRIVATE_RDS_SUBNET_AZ1_CIDR" \
      --availability-zone "$AZ1" \
      --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PRIVATE_RDS_SUBNET_AZ1_NAME}}]" \
      --query 'Subnet.SubnetId' \
      --output text)"
  fi
fi

if ! aws ec2 describe-subnets --subnet-ids "${PRIVATE_RDS_SUBNET_AZ2_ID:-missing}" --region "$REGION" >/dev/null 2>&1; then
  PRIVATE_RDS_SUBNET_AZ2_ID="$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=${PRIVATE_RDS_SUBNET_AZ2_NAME}" "Name=vpc-id,Values=${VPC_ID}" \
    --query 'Subnets[0].SubnetId' \
    --output text 2>/dev/null || true)"
  [[ "$PRIVATE_RDS_SUBNET_AZ2_ID" == "None" || "$PRIVATE_RDS_SUBNET_AZ2_ID" == "null" ]] && PRIVATE_RDS_SUBNET_AZ2_ID=""
  if [[ -z "$PRIVATE_RDS_SUBNET_AZ2_ID" ]]; then
    PRIVATE_RDS_SUBNET_AZ2_ID="$(aws ec2 create-subnet \
      --vpc-id "$VPC_ID" \
      --cidr-block "$PRIVATE_RDS_SUBNET_AZ2_CIDR" \
      --availability-zone "$AZ2" \
      --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PRIVATE_RDS_SUBNET_AZ2_NAME}}]" \
      --query 'Subnet.SubnetId' \
      --output text)"
  fi
fi

if aws ec2 describe-internet-gateways --internet-gateway-ids "${IGW_ID:-missing}" --region "$REGION" >/dev/null 2>&1; then
  echo "Internet gateway $IGW_NAME already exists, skipping creation."
else
  IGW_ID="$(aws ec2 describe-internet-gateways \
    --filters "Name=tag:Name,Values=${IGW_NAME}" "Name=attachment.vpc-id,Values=${VPC_ID}" \
    --query 'InternetGateways[0].InternetGatewayId' \
    --output text 2>/dev/null || true)"
  [[ "$IGW_ID" == "None" || "$IGW_ID" == "null" ]] && IGW_ID=""
  if [[ -z "$IGW_ID" ]]; then
    IGW_ID="$(aws ec2 create-internet-gateway \
      --region "$REGION" \
      --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${IGW_NAME}}]" \
      --query 'InternetGateway.InternetGatewayId' \
      --output text)"
  fi
fi

IGW_ATTACHMENT_VPC_ID="$(aws ec2 describe-internet-gateways \
  --internet-gateway-ids "$IGW_ID" \
  --query 'InternetGateways[0].Attachments[0].VpcId' \
  --output text 2>/dev/null || true)"
if [[ "$IGW_ATTACHMENT_VPC_ID" != "$VPC_ID" ]]; then
  aws ec2 attach-internet-gateway \
    --internet-gateway-id "$IGW_ID" \
    --vpc-id "$VPC_ID" >/dev/null 2>&1 || true
fi

if ! aws ec2 describe-route-tables --route-table-ids "${PUBLIC_RTB_ID:-missing}" --region "$REGION" >/dev/null 2>&1; then
  PUBLIC_RTB_ID="$(aws ec2 describe-route-tables \
    --filters "Name=tag:Name,Values=${PUBLIC_RTB_NAME}" "Name=vpc-id,Values=${VPC_ID}" \
    --query 'RouteTables[0].RouteTableId' \
    --output text 2>/dev/null || true)"
  [[ "$PUBLIC_RTB_ID" == "None" || "$PUBLIC_RTB_ID" == "null" ]] && PUBLIC_RTB_ID=""
  if [[ -z "$PUBLIC_RTB_ID" ]]; then
    PUBLIC_RTB_ID="$(aws ec2 create-route-table \
      --vpc-id "$VPC_ID" \
      --region "$REGION" \
      --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${PUBLIC_RTB_NAME}}]" \
      --query 'RouteTable.RouteTableId' \
      --output text)"
  fi
fi

aws ec2 create-route \
  --route-table-id "$PUBLIC_RTB_ID" \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id "$IGW_ID" >/dev/null 2>&1 || true

PUBLIC_ASSOC_AZ1="$(aws ec2 describe-route-tables \
  --route-table-ids "$PUBLIC_RTB_ID" \
  --query "RouteTables[0].Associations[?SubnetId=='${PUBLIC_SUBNET_AZ1_ID}'].RouteTableAssociationId | [0]" \
  --output text 2>/dev/null || true)"
[[ "$PUBLIC_ASSOC_AZ1" == "None" || "$PUBLIC_ASSOC_AZ1" == "null" ]] && PUBLIC_ASSOC_AZ1=""
if [[ -z "$PUBLIC_ASSOC_AZ1" ]]; then
  aws ec2 associate-route-table --route-table-id "$PUBLIC_RTB_ID" --subnet-id "$PUBLIC_SUBNET_AZ1_ID" >/dev/null 2>&1 || true
fi

PUBLIC_ASSOC_AZ2="$(aws ec2 describe-route-tables \
  --route-table-ids "$PUBLIC_RTB_ID" \
  --query "RouteTables[0].Associations[?SubnetId=='${PUBLIC_SUBNET_AZ2_ID}'].RouteTableAssociationId | [0]" \
  --output text 2>/dev/null || true)"
[[ "$PUBLIC_ASSOC_AZ2" == "None" || "$PUBLIC_ASSOC_AZ2" == "null" ]] && PUBLIC_ASSOC_AZ2=""
if [[ -z "$PUBLIC_ASSOC_AZ2" ]]; then
  aws ec2 associate-route-table --route-table-id "$PUBLIC_RTB_ID" --subnet-id "$PUBLIC_SUBNET_AZ2_ID" >/dev/null 2>&1 || true
fi

if ! aws ec2 describe-nat-gateways --nat-gateway-ids "${NAT_GATEWAY_ID_AZ1:-missing}" --region "$REGION" >/dev/null 2>&1; then
  NAT_GATEWAY_ID_AZ1="$(aws ec2 describe-nat-gateways \
    --filter "Name=tag:Name,Values=${NAT_GATEWAY_NAME_AZ1}" "Name=state,Values=pending,available" \
    --query 'NatGateways[0].NatGatewayId' \
    --output text 2>/dev/null || true)"
  [[ "$NAT_GATEWAY_ID_AZ1" == "None" || "$NAT_GATEWAY_ID_AZ1" == "null" ]] && NAT_GATEWAY_ID_AZ1=""
fi

EIP_AZ1_CHECK="$(aws ec2 describe-addresses --allocation-ids "${EIP_AZ1:-missing}" --query 'Addresses[0].AllocationId' --output text 2>/dev/null || true)"
[[ "$EIP_AZ1_CHECK" == "None" || "$EIP_AZ1_CHECK" == "null" ]] && EIP_AZ1_CHECK=""
if [[ -z "${EIP_AZ1:-}" || -z "$EIP_AZ1_CHECK" ]]; then
  if [[ -n "${NAT_GATEWAY_ID_AZ1:-}" ]]; then
    EIP_AZ1="$(aws ec2 describe-nat-gateways --nat-gateway-ids "$NAT_GATEWAY_ID_AZ1" --query 'NatGateways[0].NatGatewayAddresses[0].AllocationId' --output text 2>/dev/null || true)"
    [[ "$EIP_AZ1" == "None" || "$EIP_AZ1" == "null" ]] && EIP_AZ1=""
  fi
fi

if [[ -z "${NAT_GATEWAY_ID_AZ1:-}" ]]; then
  if [[ -z "${EIP_AZ1:-}" ]]; then
    EIP_AZ1="$(aws ec2 allocate-address \
      --domain vpc \
      --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=${NAT_GATEWAY_NAME_AZ1}}]" \
      --query 'AllocationId' \
      --output text)"
  fi
  NAT_GATEWAY_ID_AZ1="$(aws ec2 create-nat-gateway \
    --subnet-id "$PUBLIC_SUBNET_AZ1_ID" \
    --allocation-id "$EIP_AZ1" \
    --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=${NAT_GATEWAY_NAME_AZ1}}]" \
    --query 'NatGateway.NatGatewayId' \
    --output text)"
fi

if ! aws ec2 describe-nat-gateways --nat-gateway-ids "${NAT_GATEWAY_ID_AZ2:-missing}" --region "$REGION" >/dev/null 2>&1; then
  NAT_GATEWAY_ID_AZ2="$(aws ec2 describe-nat-gateways \
    --filter "Name=tag:Name,Values=${NAT_GATEWAY_NAME_AZ2}" "Name=state,Values=pending,available" \
    --query 'NatGateways[0].NatGatewayId' \
    --output text 2>/dev/null || true)"
  [[ "$NAT_GATEWAY_ID_AZ2" == "None" || "$NAT_GATEWAY_ID_AZ2" == "null" ]] && NAT_GATEWAY_ID_AZ2=""
fi

EIP_AZ2_CHECK="$(aws ec2 describe-addresses --allocation-ids "${EIP_AZ2:-missing}" --query 'Addresses[0].AllocationId' --output text 2>/dev/null || true)"
[[ "$EIP_AZ2_CHECK" == "None" || "$EIP_AZ2_CHECK" == "null" ]] && EIP_AZ2_CHECK=""
if [[ -z "${EIP_AZ2:-}" || -z "$EIP_AZ2_CHECK" ]]; then
  if [[ -n "${NAT_GATEWAY_ID_AZ2:-}" ]]; then
    EIP_AZ2="$(aws ec2 describe-nat-gateways --nat-gateway-ids "$NAT_GATEWAY_ID_AZ2" --query 'NatGateways[0].NatGatewayAddresses[0].AllocationId' --output text 2>/dev/null || true)"
    [[ "$EIP_AZ2" == "None" || "$EIP_AZ2" == "null" ]] && EIP_AZ2=""
  fi
fi

if [[ -z "${NAT_GATEWAY_ID_AZ2:-}" ]]; then
  if [[ -z "${EIP_AZ2:-}" ]]; then
    EIP_AZ2="$(aws ec2 allocate-address \
      --domain vpc \
      --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=${NAT_GATEWAY_NAME_AZ2}}]" \
      --query 'AllocationId' \
      --output text)"
  fi
  NAT_GATEWAY_ID_AZ2="$(aws ec2 create-nat-gateway \
    --subnet-id "$PUBLIC_SUBNET_AZ2_ID" \
    --allocation-id "$EIP_AZ2" \
    --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=${NAT_GATEWAY_NAME_AZ2}}]" \
    --query 'NatGateway.NatGatewayId' \
    --output text)"
fi

wait_for_nat_gateway "$NAT_GATEWAY_ID_AZ1" &
wait_for_nat_gateway "$NAT_GATEWAY_ID_AZ2" &
wait

if ! aws ec2 describe-route-tables --route-table-ids "${PRIVATE_RTB_AZ1_ID:-missing}" --region "$REGION" >/dev/null 2>&1; then
  PRIVATE_RTB_AZ1_ID="$(aws ec2 describe-route-tables \
    --filters "Name=tag:Name,Values=${PRIVATE_RTB_AZ1_NAME}" "Name=vpc-id,Values=${VPC_ID}" \
    --query 'RouteTables[0].RouteTableId' \
    --output text 2>/dev/null || true)"
  [[ "$PRIVATE_RTB_AZ1_ID" == "None" || "$PRIVATE_RTB_AZ1_ID" == "null" ]] && PRIVATE_RTB_AZ1_ID=""
  if [[ -z "$PRIVATE_RTB_AZ1_ID" ]]; then
    PRIVATE_RTB_AZ1_ID="$(aws ec2 create-route-table \
      --vpc-id "$VPC_ID" \
      --region "$REGION" \
      --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${PRIVATE_RTB_AZ1_NAME}}]" \
      --query 'RouteTable.RouteTableId' \
      --output text)"
  fi
fi

if ! aws ec2 describe-route-tables --route-table-ids "${PRIVATE_RTB_AZ2_ID:-missing}" --region "$REGION" >/dev/null 2>&1; then
  PRIVATE_RTB_AZ2_ID="$(aws ec2 describe-route-tables \
    --filters "Name=tag:Name,Values=${PRIVATE_RTB_AZ2_NAME}" "Name=vpc-id,Values=${VPC_ID}" \
    --query 'RouteTables[0].RouteTableId' \
    --output text 2>/dev/null || true)"
  [[ "$PRIVATE_RTB_AZ2_ID" == "None" || "$PRIVATE_RTB_AZ2_ID" == "null" ]] && PRIVATE_RTB_AZ2_ID=""
  if [[ -z "$PRIVATE_RTB_AZ2_ID" ]]; then
    PRIVATE_RTB_AZ2_ID="$(aws ec2 create-route-table \
      --vpc-id "$VPC_ID" \
      --region "$REGION" \
      --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${PRIVATE_RTB_AZ2_NAME}}]" \
      --query 'RouteTable.RouteTableId' \
      --output text)"
  fi
fi

aws ec2 create-route \
  --route-table-id "$PRIVATE_RTB_AZ1_ID" \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id "$NAT_GATEWAY_ID_AZ1" >/dev/null 2>&1 || true
aws ec2 create-route \
  --route-table-id "$PRIVATE_RTB_AZ2_ID" \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id "$NAT_GATEWAY_ID_AZ2" >/dev/null 2>&1 || true

PRIVATE_ASSOC_AZ1="$(aws ec2 describe-route-tables \
  --route-table-ids "$PRIVATE_RTB_AZ1_ID" \
  --query "RouteTables[0].Associations[?SubnetId=='${PRIVATE_SUBNET_AZ1_ID}'].RouteTableAssociationId | [0]" \
  --output text 2>/dev/null || true)"
[[ "$PRIVATE_ASSOC_AZ1" == "None" || "$PRIVATE_ASSOC_AZ1" == "null" ]] && PRIVATE_ASSOC_AZ1=""
if [[ -z "$PRIVATE_ASSOC_AZ1" ]]; then
  aws ec2 associate-route-table --route-table-id "$PRIVATE_RTB_AZ1_ID" --subnet-id "$PRIVATE_SUBNET_AZ1_ID" >/dev/null 2>&1 || true
fi

PRIVATE_ASSOC_AZ2="$(aws ec2 describe-route-tables \
  --route-table-ids "$PRIVATE_RTB_AZ2_ID" \
  --query "RouteTables[0].Associations[?SubnetId=='${PRIVATE_SUBNET_AZ2_ID}'].RouteTableAssociationId | [0]" \
  --output text 2>/dev/null || true)"
[[ "$PRIVATE_ASSOC_AZ2" == "None" || "$PRIVATE_ASSOC_AZ2" == "null" ]] && PRIVATE_ASSOC_AZ2=""
if [[ -z "$PRIVATE_ASSOC_AZ2" ]]; then
  aws ec2 associate-route-table --route-table-id "$PRIVATE_RTB_AZ2_ID" --subnet-id "$PRIVATE_SUBNET_AZ2_ID" >/dev/null 2>&1 || true
fi

grep -vE '^(VPC_ID|PUBLIC_SUBNET_AZ1_ID|PUBLIC_SUBNET_AZ2_ID|PRIVATE_SUBNET_AZ1_ID|PRIVATE_SUBNET_AZ2_ID|PRIVATE_RDS_SUBNET_AZ1_ID|PRIVATE_RDS_SUBNET_AZ2_ID|IGW_ID|PUBLIC_RTB_ID|PRIVATE_RTB_AZ1_ID|PRIVATE_RTB_AZ2_ID|EIP_AZ1|EIP_AZ2|NAT_GATEWAY_ID_AZ1|NAT_GATEWAY_ID_AZ2)=' "$VARIABLES_FILE" > "$VARIABLES_FILE.tmp" || true
{
  cat "$VARIABLES_FILE.tmp"
  echo "VPC_ID=$VPC_ID"
  echo "PUBLIC_SUBNET_AZ1_ID=$PUBLIC_SUBNET_AZ1_ID"
  echo "PUBLIC_SUBNET_AZ2_ID=$PUBLIC_SUBNET_AZ2_ID"
  echo "PRIVATE_SUBNET_AZ1_ID=$PRIVATE_SUBNET_AZ1_ID"
  echo "PRIVATE_SUBNET_AZ2_ID=$PRIVATE_SUBNET_AZ2_ID"
  echo "PRIVATE_RDS_SUBNET_AZ1_ID=$PRIVATE_RDS_SUBNET_AZ1_ID"
  echo "PRIVATE_RDS_SUBNET_AZ2_ID=$PRIVATE_RDS_SUBNET_AZ2_ID"
  echo "IGW_ID=$IGW_ID"
  echo "PUBLIC_RTB_ID=$PUBLIC_RTB_ID"
  echo "PRIVATE_RTB_AZ1_ID=$PRIVATE_RTB_AZ1_ID"
  echo "PRIVATE_RTB_AZ2_ID=$PRIVATE_RTB_AZ2_ID"
  echo "EIP_AZ1=$EIP_AZ1"
  echo "EIP_AZ2=$EIP_AZ2"
  echo "NAT_GATEWAY_ID_AZ1=$NAT_GATEWAY_ID_AZ1"
  echo "NAT_GATEWAY_ID_AZ2=$NAT_GATEWAY_ID_AZ2"
} > "$VARIABLES_FILE"
rm -f "$VARIABLES_FILE.tmp"

echo "✅ VPC networking ready."
