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

if ! aws ec2 describe-vpcs --vpc-ids "${VPC_ID:-missing}" --region "$REGION" >/dev/null 2>&1; then
  VPC_ID="$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=${VPC_NAME}" \
    --query 'Vpcs[0].VpcId' \
    --output text 2>/dev/null || true)"
  [[ "$VPC_ID" == "None" || "$VPC_ID" == "null" ]] && VPC_ID=""
fi

if [[ -z "${VPC_ID:-}" ]]; then
  echo "✅ VPC already removed."
  exit 0
fi

if ! aws ec2 describe-nat-gateways --nat-gateway-ids "${NAT_GATEWAY_ID_AZ1:-missing}" --region "$REGION" >/dev/null 2>&1; then
  NAT_GATEWAY_ID_AZ1="$(aws ec2 describe-nat-gateways \
    --filter "Name=tag:Name,Values=${NAT_GATEWAY_NAME_AZ1}" "Name=state,Values=pending,available,deleting,failed" \
    --query 'NatGateways[0].NatGatewayId' \
    --output text 2>/dev/null || true)"
  [[ "$NAT_GATEWAY_ID_AZ1" == "None" || "$NAT_GATEWAY_ID_AZ1" == "null" ]] && NAT_GATEWAY_ID_AZ1=""
fi

if ! aws ec2 describe-nat-gateways --nat-gateway-ids "${NAT_GATEWAY_ID_AZ2:-missing}" --region "$REGION" >/dev/null 2>&1; then
  NAT_GATEWAY_ID_AZ2="$(aws ec2 describe-nat-gateways \
    --filter "Name=tag:Name,Values=${NAT_GATEWAY_NAME_AZ2}" "Name=state,Values=pending,available,deleting,failed" \
    --query 'NatGateways[0].NatGatewayId' \
    --output text 2>/dev/null || true)"
  [[ "$NAT_GATEWAY_ID_AZ2" == "None" || "$NAT_GATEWAY_ID_AZ2" == "null" ]] && NAT_GATEWAY_ID_AZ2=""
fi

if [[ -n "${NAT_GATEWAY_ID_AZ1:-}" ]]; then
  aws ec2 delete-nat-gateway --nat-gateway-id "$NAT_GATEWAY_ID_AZ1" >/dev/null 2>&1 || true
  aws ec2 wait nat-gateway-deleted --nat-gateway-ids "$NAT_GATEWAY_ID_AZ1" >/dev/null 2>&1 || true
fi

if [[ -n "${NAT_GATEWAY_ID_AZ2:-}" ]]; then
  aws ec2 delete-nat-gateway --nat-gateway-id "$NAT_GATEWAY_ID_AZ2" >/dev/null 2>&1 || true
  aws ec2 wait nat-gateway-deleted --nat-gateway-ids "$NAT_GATEWAY_ID_AZ2" >/dev/null 2>&1 || true
fi

aws ec2 release-address --allocation-id "${EIP_AZ1:-missing}" >/dev/null 2>&1 || true
aws ec2 release-address --allocation-id "${EIP_AZ2:-missing}" >/dev/null 2>&1 || true

if ! aws ec2 describe-internet-gateways --internet-gateway-ids "${IGW_ID:-missing}" --region "$REGION" >/dev/null 2>&1; then
  IGW_ID="$(aws ec2 describe-internet-gateways \
    --filters "Name=tag:Name,Values=${IGW_NAME}" "Name=attachment.vpc-id,Values=${VPC_ID}" \
    --query 'InternetGateways[0].InternetGatewayId' \
    --output text 2>/dev/null || true)"
  [[ "$IGW_ID" == "None" || "$IGW_ID" == "null" ]] && IGW_ID=""
fi

if [[ -n "${IGW_ID:-}" ]]; then
  aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" >/dev/null 2>&1 || true
  aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" >/dev/null 2>&1 || true
fi

if ! aws ec2 describe-route-tables --route-table-ids "${PUBLIC_RTB_ID:-missing}" --region "$REGION" >/dev/null 2>&1; then
  PUBLIC_RTB_ID="$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=${PUBLIC_RTB_NAME}" "Name=vpc-id,Values=${VPC_ID}" --query 'RouteTables[0].RouteTableId' --output text 2>/dev/null || true)"
  [[ "$PUBLIC_RTB_ID" == "None" || "$PUBLIC_RTB_ID" == "null" ]] && PUBLIC_RTB_ID=""
fi

if ! aws ec2 describe-route-tables --route-table-ids "${PRIVATE_RTB_AZ1_ID:-missing}" --region "$REGION" >/dev/null 2>&1; then
  PRIVATE_RTB_AZ1_ID="$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=${PRIVATE_RTB_AZ1_NAME}" "Name=vpc-id,Values=${VPC_ID}" --query 'RouteTables[0].RouteTableId' --output text 2>/dev/null || true)"
  [[ "$PRIVATE_RTB_AZ1_ID" == "None" || "$PRIVATE_RTB_AZ1_ID" == "null" ]] && PRIVATE_RTB_AZ1_ID=""
fi

if ! aws ec2 describe-route-tables --route-table-ids "${PRIVATE_RTB_AZ2_ID:-missing}" --region "$REGION" >/dev/null 2>&1; then
  PRIVATE_RTB_AZ2_ID="$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=${PRIVATE_RTB_AZ2_NAME}" "Name=vpc-id,Values=${VPC_ID}" --query 'RouteTables[0].RouteTableId' --output text 2>/dev/null || true)"
  [[ "$PRIVATE_RTB_AZ2_ID" == "None" || "$PRIVATE_RTB_AZ2_ID" == "null" ]] && PRIVATE_RTB_AZ2_ID=""
fi

for ROUTE_TABLE_ID in "${PUBLIC_RTB_ID:-}" "${PRIVATE_RTB_AZ1_ID:-}" "${PRIVATE_RTB_AZ2_ID:-}"; do
  [[ -n "$ROUTE_TABLE_ID" ]] || continue
  ASSOCIATION_IDS="$(aws ec2 describe-route-tables \
    --route-table-ids "$ROUTE_TABLE_ID" \
    --query 'RouteTables[0].Associations[?Main==`false`].RouteTableAssociationId' \
    --output text 2>/dev/null || true)"
  for ASSOCIATION_ID in $ASSOCIATION_IDS; do
    aws ec2 disassociate-route-table --association-id "$ASSOCIATION_ID" >/dev/null 2>&1 || true
  done
  aws ec2 delete-route-table --route-table-id "$ROUTE_TABLE_ID" >/dev/null 2>&1 || true
done

if ! aws ec2 describe-subnets --subnet-ids "${PUBLIC_SUBNET_AZ1_ID:-missing}" --region "$REGION" >/dev/null 2>&1; then
  PUBLIC_SUBNET_AZ1_ID="$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=${PUBLIC_SUBNET_AZ1_NAME}" "Name=vpc-id,Values=${VPC_ID}" --query 'Subnets[0].SubnetId' --output text 2>/dev/null || true)"
  [[ "$PUBLIC_SUBNET_AZ1_ID" == "None" || "$PUBLIC_SUBNET_AZ1_ID" == "null" ]] && PUBLIC_SUBNET_AZ1_ID=""
fi

if ! aws ec2 describe-subnets --subnet-ids "${PUBLIC_SUBNET_AZ2_ID:-missing}" --region "$REGION" >/dev/null 2>&1; then
  PUBLIC_SUBNET_AZ2_ID="$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=${PUBLIC_SUBNET_AZ2_NAME}" "Name=vpc-id,Values=${VPC_ID}" --query 'Subnets[0].SubnetId' --output text 2>/dev/null || true)"
  [[ "$PUBLIC_SUBNET_AZ2_ID" == "None" || "$PUBLIC_SUBNET_AZ2_ID" == "null" ]] && PUBLIC_SUBNET_AZ2_ID=""
fi

if ! aws ec2 describe-subnets --subnet-ids "${PRIVATE_SUBNET_AZ1_ID:-missing}" --region "$REGION" >/dev/null 2>&1; then
  PRIVATE_SUBNET_AZ1_ID="$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=${PRIVATE_SUBNET_AZ1_NAME}" "Name=vpc-id,Values=${VPC_ID}" --query 'Subnets[0].SubnetId' --output text 2>/dev/null || true)"
  [[ "$PRIVATE_SUBNET_AZ1_ID" == "None" || "$PRIVATE_SUBNET_AZ1_ID" == "null" ]] && PRIVATE_SUBNET_AZ1_ID=""
fi

if ! aws ec2 describe-subnets --subnet-ids "${PRIVATE_SUBNET_AZ2_ID:-missing}" --region "$REGION" >/dev/null 2>&1; then
  PRIVATE_SUBNET_AZ2_ID="$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=${PRIVATE_SUBNET_AZ2_NAME}" "Name=vpc-id,Values=${VPC_ID}" --query 'Subnets[0].SubnetId' --output text 2>/dev/null || true)"
  [[ "$PRIVATE_SUBNET_AZ2_ID" == "None" || "$PRIVATE_SUBNET_AZ2_ID" == "null" ]] && PRIVATE_SUBNET_AZ2_ID=""
fi

if ! aws ec2 describe-subnets --subnet-ids "${PRIVATE_RDS_SUBNET_AZ1_ID:-missing}" --region "$REGION" >/dev/null 2>&1; then
  PRIVATE_RDS_SUBNET_AZ1_ID="$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=${PRIVATE_RDS_SUBNET_AZ1_NAME}" "Name=vpc-id,Values=${VPC_ID}" --query 'Subnets[0].SubnetId' --output text 2>/dev/null || true)"
  [[ "$PRIVATE_RDS_SUBNET_AZ1_ID" == "None" || "$PRIVATE_RDS_SUBNET_AZ1_ID" == "null" ]] && PRIVATE_RDS_SUBNET_AZ1_ID=""
fi

if ! aws ec2 describe-subnets --subnet-ids "${PRIVATE_RDS_SUBNET_AZ2_ID:-missing}" --region "$REGION" >/dev/null 2>&1; then
  PRIVATE_RDS_SUBNET_AZ2_ID="$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=${PRIVATE_RDS_SUBNET_AZ2_NAME}" "Name=vpc-id,Values=${VPC_ID}" --query 'Subnets[0].SubnetId' --output text 2>/dev/null || true)"
  [[ "$PRIVATE_RDS_SUBNET_AZ2_ID" == "None" || "$PRIVATE_RDS_SUBNET_AZ2_ID" == "null" ]] && PRIVATE_RDS_SUBNET_AZ2_ID=""
fi

for SUBNET_ID in \
  "${PUBLIC_SUBNET_AZ1_ID:-}" \
  "${PUBLIC_SUBNET_AZ2_ID:-}" \
  "${PRIVATE_SUBNET_AZ1_ID:-}" \
  "${PRIVATE_SUBNET_AZ2_ID:-}" \
  "${PRIVATE_RDS_SUBNET_AZ1_ID:-}" \
  "${PRIVATE_RDS_SUBNET_AZ2_ID:-}"; do
  [[ -n "$SUBNET_ID" ]] || continue
  aws ec2 delete-subnet --subnet-id "$SUBNET_ID" >/dev/null 2>&1 || true
done

aws ec2 delete-vpc --vpc-id "$VPC_ID" >/dev/null 2>&1 || true

grep -vE '^(VPC_ID|PUBLIC_SUBNET_AZ1_ID|PUBLIC_SUBNET_AZ2_ID|PRIVATE_SUBNET_AZ1_ID|PRIVATE_SUBNET_AZ2_ID|PRIVATE_RDS_SUBNET_AZ1_ID|PRIVATE_RDS_SUBNET_AZ2_ID|IGW_ID|PUBLIC_RTB_ID|PRIVATE_RTB_AZ1_ID|PRIVATE_RTB_AZ2_ID|EIP_AZ1|EIP_AZ2|NAT_GATEWAY_ID_AZ1|NAT_GATEWAY_ID_AZ2)=' "$VARIABLES_FILE" > "$VARIABLES_FILE.tmp" || true
mv "$VARIABLES_FILE.tmp" "$VARIABLES_FILE"

echo "✅ VPC cleanup completed."
