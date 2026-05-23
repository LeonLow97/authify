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

if [[ -z "${VPC_ID:-}" || -z "${PUBLIC_SUBNET_AZ1_ID:-}" || -z "${PUBLIC_SUBNET_AZ2_ID:-}" || -z "${API_GATEWAY_INSTANCE_ID_AZ1:-}" || -z "${API_GATEWAY_INSTANCE_ID_AZ2:-}" ]]; then
  echo "Missing VPC, public subnet, or API Gateway instance values. Run the earlier deploy steps first."
  exit 1
fi

if ! aws ec2 describe-security-groups --group-ids "${ALB_SG_ID:-missing}" --region "$REGION" >/dev/null 2>&1; then
  ALB_SG_ID="$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=${ALB_SG_NAME}" "Name=vpc-id,Values=${VPC_ID}" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || true)"
  [[ "$ALB_SG_ID" == "None" || "$ALB_SG_ID" == "null" ]] && ALB_SG_ID=""
fi

if [[ -z "${ALB_SG_ID:-}" ]]; then
  echo "Missing ALB security group."
  exit 1
fi

if ! aws elbv2 describe-load-balancers --load-balancer-arns "${ALB_ARN:-missing}" >/dev/null 2>&1; then
  ALB_ARN="$(aws elbv2 describe-load-balancers --names "${ALB_NAME}" --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || true)"
  [[ "$ALB_ARN" == "None" || "$ALB_ARN" == "null" ]] && ALB_ARN=""
fi

if [[ -z "${ALB_ARN:-}" ]]; then
  echo "Creating load balancer $ALB_NAME ..."
  ALB_ARN="$(aws elbv2 create-load-balancer \
    --name "${ALB_NAME}" \
    --subnets "${PUBLIC_SUBNET_AZ1_ID}" "${PUBLIC_SUBNET_AZ2_ID}" \
    --security-groups "${ALB_SG_ID}" \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)"
else
  echo "Load balancer $ALB_NAME already exists, skipping creation."
fi

aws elbv2 wait load-balancer-available --load-balancer-arns "$ALB_ARN"

if ! aws elbv2 describe-target-groups --target-group-arns "${ALB_TARGET_GROUP_ARN:-missing}" >/dev/null 2>&1; then
  ALB_TARGET_GROUP_ARN="$(aws elbv2 describe-target-groups --names "${ALB_TARGET_GROUP_NAME}" --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || true)"
  [[ "$ALB_TARGET_GROUP_ARN" == "None" || "$ALB_TARGET_GROUP_ARN" == "null" ]] && ALB_TARGET_GROUP_ARN=""
fi

if [[ -z "${ALB_TARGET_GROUP_ARN:-}" ]]; then
  echo "Creating target group $ALB_TARGET_GROUP_NAME ..."
  ALB_TARGET_GROUP_ARN="$(aws elbv2 create-target-group \
    --name "${ALB_TARGET_GROUP_NAME}" \
    --protocol HTTP \
    --port "${PORT_API_GATEWAY}" \
    --vpc-id "${VPC_ID}" \
    --health-check-protocol HTTP \
    --health-check-port "${PORT_API_GATEWAY}" \
    --health-check-path "${ALB_HEALTHCHECK_PATH}" \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 5 \
    --unhealthy-threshold-count 2 \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)"
else
  echo "Target group $ALB_TARGET_GROUP_NAME already exists, skipping creation."
  aws elbv2 modify-target-group \
    --target-group-arn "${ALB_TARGET_GROUP_ARN}" \
    --health-check-protocol HTTP \
    --health-check-port "${PORT_API_GATEWAY}" \
    --health-check-path "${ALB_HEALTHCHECK_PATH}" \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 5 \
    --unhealthy-threshold-count 2 >/dev/null
fi

aws elbv2 register-targets \
  --target-group-arn "${ALB_TARGET_GROUP_ARN}" \
  --targets "Id=${API_GATEWAY_INSTANCE_ID_AZ1}" "Id=${API_GATEWAY_INSTANCE_ID_AZ2}" >/dev/null 2>&1 || true

if ! aws elbv2 describe-listeners --listener-arns "${ALB_LISTENER_ARN:-missing}" >/dev/null 2>&1; then
  ALB_LISTENER_ARN="$(aws elbv2 describe-listeners \
    --load-balancer-arn "${ALB_ARN}" \
    --query 'Listeners[?Port==`80`].ListenerArn | [0]' \
    --output text 2>/dev/null || true)"
  [[ "$ALB_LISTENER_ARN" == "None" || "$ALB_LISTENER_ARN" == "null" ]] && ALB_LISTENER_ARN=""
fi

if [[ -z "${ALB_LISTENER_ARN:-}" ]]; then
  echo "Creating ALB listener on port 80 ..."
  ALB_LISTENER_ARN="$(aws elbv2 create-listener \
    --load-balancer-arn "${ALB_ARN}" \
    --protocol HTTP \
    --port 80 \
    --default-actions "Type=forward,TargetGroupArn=${ALB_TARGET_GROUP_ARN}" \
    --query 'Listeners[0].ListenerArn' \
    --output text)"
else
  aws elbv2 modify-listener \
    --listener-arn "${ALB_LISTENER_ARN}" \
    --default-actions "Type=forward,TargetGroupArn=${ALB_TARGET_GROUP_ARN}" >/dev/null
fi

ALB_DNS_NAME="$(aws elbv2 describe-load-balancers \
  --load-balancer-arns "${ALB_ARN}" \
  --query 'LoadBalancers[0].DNSName' \
  --output text)"

grep -vE '^(ALB_SG_ID|ALB_ARN|ALB_TARGET_GROUP_ARN|ALB_LISTENER_ARN|ALB_DNS_NAME)=' "$VARIABLES_FILE" > "$VARIABLES_FILE.tmp" || true
{
  cat "$VARIABLES_FILE.tmp"
  echo "ALB_SG_ID=$ALB_SG_ID"
  echo "ALB_ARN=$ALB_ARN"
  echo "ALB_TARGET_GROUP_ARN=$ALB_TARGET_GROUP_ARN"
  echo "ALB_LISTENER_ARN=$ALB_LISTENER_ARN"
  echo "ALB_DNS_NAME=$ALB_DNS_NAME"
} > "$VARIABLES_FILE"
rm -f "$VARIABLES_FILE.tmp"

echo "Waiting for ALB targets to start serving ..."
sleep 30

ALB_HEALTHCHECK_URL="http://${ALB_DNS_NAME}${ALB_HEALTHCHECK_PATH}"
echo "Try manually: curl -i ${ALB_HEALTHCHECK_URL}"

for attempt in $(seq 1 30); do
  HTTP_STATUS="$(curl --connect-timeout 5 -o /dev/null -sS -w '%{http_code}' "${ALB_HEALTHCHECK_URL}" 2>/dev/null || true)"
  echo "ALB health check attempt ${attempt}/30: status=${HTTP_STATUS:-curl_failed}"
  if [[ "$HTTP_STATUS" == "200" ]]; then
    echo "✅ ALB health check passed at ${ALB_HEALTHCHECK_URL}"
    exit 0
  fi
  sleep 10
done

echo "ALB health check failed for ${ALB_HEALTHCHECK_URL}"
echo "Manual check: curl -i ${ALB_HEALTHCHECK_URL}"
exit 1
