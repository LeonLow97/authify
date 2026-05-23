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

if aws elasticache describe-cache-clusters \
  --cache-cluster-id "${ELASTICACHE_CLUSTER_ID}" \
  --region "${REGION}" >/dev/null 2>&1; then
  aws elasticache delete-cache-cluster \
    --cache-cluster-id "${ELASTICACHE_CLUSTER_ID}" \
    --region "${REGION}" >/dev/null 2>&1 || true
  aws elasticache wait cache-cluster-deleted \
    --cache-cluster-id "${ELASTICACHE_CLUSTER_ID}" \
    --region "${REGION}"
fi

if aws elasticache describe-cache-subnet-groups \
  --cache-subnet-group-name "${ELASTICACHE_SUBNET_GROUP_NAME}" \
  --region "${REGION}" >/dev/null 2>&1; then
  aws elasticache delete-cache-subnet-group \
    --cache-subnet-group-name "${ELASTICACHE_SUBNET_GROUP_NAME}" \
    --region "${REGION}" >/dev/null
fi

grep -vE '^(ELASTICACHE_CLUSTER_ID|ELASTICACHE_SUBNET_GROUP_NAME|ELASTICACHE_ENDPOINT|ELASTICACHE_PORT|ELASTICACHE_PASSWORD)=' "$VARIABLES_FILE" > "$VARIABLES_FILE.tmp" || true
mv "$VARIABLES_FILE.tmp" "$VARIABLES_FILE"

echo "✅ ElastiCache cleanup completed."
