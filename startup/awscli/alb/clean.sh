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

if ! aws elbv2 describe-load-balancers --load-balancer-arns "${ALB_ARN:-missing}" >/dev/null 2>&1; then
  ALB_ARN="$(aws elbv2 describe-load-balancers --names "${ALB_NAME}" --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || true)"
  [[ "$ALB_ARN" == "None" || "$ALB_ARN" == "null" ]] && ALB_ARN=""
fi

if ! aws elbv2 describe-target-groups --target-group-arns "${ALB_TARGET_GROUP_ARN:-missing}" >/dev/null 2>&1; then
  ALB_TARGET_GROUP_ARN="$(aws elbv2 describe-target-groups --names "${ALB_TARGET_GROUP_NAME}" --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || true)"
  [[ "$ALB_TARGET_GROUP_ARN" == "None" || "$ALB_TARGET_GROUP_ARN" == "null" ]] && ALB_TARGET_GROUP_ARN=""
fi

if [[ -n "${ALB_TARGET_GROUP_ARN:-}" ]]; then
  aws elbv2 deregister-targets \
    --target-group-arn "${ALB_TARGET_GROUP_ARN}" \
    --targets "Id=${API_GATEWAY_INSTANCE_ID_AZ1:-i-missing}" "Id=${API_GATEWAY_INSTANCE_ID_AZ2:-i-missing}" >/dev/null 2>&1 || true
fi

if [[ -n "${ALB_ARN:-}" ]]; then
  if ! aws elbv2 describe-listeners --listener-arns "${ALB_LISTENER_ARN:-missing}" >/dev/null 2>&1; then
    ALB_LISTENER_ARN="$(aws elbv2 describe-listeners \
      --load-balancer-arn "${ALB_ARN}" \
      --query 'Listeners[?Port==`80`].ListenerArn | [0]' \
      --output text 2>/dev/null || true)"
    [[ "$ALB_LISTENER_ARN" == "None" || "$ALB_LISTENER_ARN" == "null" ]] && ALB_LISTENER_ARN=""
  fi

  if [[ -n "${ALB_LISTENER_ARN:-}" ]]; then
    aws elbv2 delete-listener --listener-arn "${ALB_LISTENER_ARN}" >/dev/null 2>&1 || true
  fi

  aws elbv2 delete-load-balancer --load-balancer-arn "${ALB_ARN}" >/dev/null 2>&1 || true
  aws elbv2 wait load-balancers-deleted --load-balancer-arns "${ALB_ARN}" >/dev/null 2>&1 || true
fi

if [[ -n "${ALB_TARGET_GROUP_ARN:-}" ]]; then
  aws elbv2 delete-target-group --target-group-arn "${ALB_TARGET_GROUP_ARN}" >/dev/null 2>&1 || true
fi

grep -vE '^(ALB_ARN|ALB_TARGET_GROUP_ARN|ALB_LISTENER_ARN|ALB_DNS_NAME)=' "$VARIABLES_FILE" > "$VARIABLES_FILE.tmp" || true
mv "$VARIABLES_FILE.tmp" "$VARIABLES_FILE"

echo "✅ ALB cleanup completed."
