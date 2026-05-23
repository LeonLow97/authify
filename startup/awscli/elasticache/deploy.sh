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

if [[ -z "${PRIVATE_RDS_SUBNET_AZ1_ID:-}" || -z "${PRIVATE_RDS_SUBNET_AZ2_ID:-}" || -z "${ELASTICACHE_SG_ID:-}" ]]; then
  echo "Missing private subnet or ElastiCache security group values. Run VPC and security-group scripts first."
  exit 1
fi

if aws elasticache describe-cache-subnet-groups \
  --cache-subnet-group-name "${ELASTICACHE_SUBNET_GROUP_NAME}" \
  --region "${REGION}" >/dev/null 2>&1; then
  echo "ElastiCache subnet group $ELASTICACHE_SUBNET_GROUP_NAME already exists, skipping creation."
else
  echo "Creating ElastiCache subnet group $ELASTICACHE_SUBNET_GROUP_NAME ..."
  aws elasticache create-cache-subnet-group \
    --cache-subnet-group-name "${ELASTICACHE_SUBNET_GROUP_NAME}" \
    --cache-subnet-group-description "Authify Redis subnet group" \
    --subnet-ids "${PRIVATE_RDS_SUBNET_AZ1_ID}" "${PRIVATE_RDS_SUBNET_AZ2_ID}" \
    --region "${REGION}" >/dev/null
fi

if aws elasticache describe-cache-clusters \
  --cache-cluster-id "${ELASTICACHE_CLUSTER_ID}" \
  --region "${REGION}" >/dev/null 2>&1; then
  echo "ElastiCache cluster $ELASTICACHE_CLUSTER_ID already exists, skipping creation."
else
  echo "Creating ElastiCache cluster $ELASTICACHE_CLUSTER_ID ..."
  aws elasticache create-cache-cluster \
    --cache-cluster-id "${ELASTICACHE_CLUSTER_ID}" \
    --engine "${ELASTICACHE_ENGINE}" \
    --cache-node-type "${ELASTICACHE_NODE_TYPE}" \
    --num-cache-nodes 1 \
    --cache-subnet-group-name "${ELASTICACHE_SUBNET_GROUP_NAME}" \
    --security-group-ids "${ELASTICACHE_SG_ID}" \
    --region "${REGION}" >/dev/null
fi

aws elasticache wait cache-cluster-available \
  --cache-cluster-id "${ELASTICACHE_CLUSTER_ID}" \
  --region "${REGION}"

ELASTICACHE_ENDPOINT="$(aws elasticache describe-cache-clusters \
  --cache-cluster-id "${ELASTICACHE_CLUSTER_ID}" \
  --show-cache-node-info \
  --query 'CacheClusters[0].CacheNodes[0].Endpoint.Address' \
  --output text)"
ELASTICACHE_PORT="$(aws elasticache describe-cache-clusters \
  --cache-cluster-id "${ELASTICACHE_CLUSTER_ID}" \
  --show-cache-node-info \
  --query 'CacheClusters[0].CacheNodes[0].Endpoint.Port' \
  --output text)"

grep -vE '^(ELASTICACHE_CLUSTER_ID|ELASTICACHE_SUBNET_GROUP_NAME|ELASTICACHE_ENDPOINT|ELASTICACHE_PORT|ELASTICACHE_PASSWORD)=' "$VARIABLES_FILE" > "$VARIABLES_FILE.tmp" || true
{
  cat "$VARIABLES_FILE.tmp"
  echo "ELASTICACHE_CLUSTER_ID=$ELASTICACHE_CLUSTER_ID"
  echo "ELASTICACHE_SUBNET_GROUP_NAME=$ELASTICACHE_SUBNET_GROUP_NAME"
  echo "ELASTICACHE_ENDPOINT=$ELASTICACHE_ENDPOINT"
  echo "ELASTICACHE_PORT=$ELASTICACHE_PORT"
  echo "ELASTICACHE_PASSWORD=$ELASTICACHE_PASSWORD"
} > "$VARIABLES_FILE"
rm -f "$VARIABLES_FILE.tmp"

echo "✅ ElastiCache ready: $ELASTICACHE_ENDPOINT:$ELASTICACHE_PORT"
