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

POLICIES=(
  "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
  "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
)

for policy in "${POLICIES[@]}"; do
  aws iam detach-role-policy --role-name "${EC2_ROLE_NAME}" --policy-arn "${policy}" >/dev/null 2>&1 || true
done

aws iam remove-role-from-instance-profile \
  --instance-profile-name "${EC2_INSTANCE_PROFILE_NAME}" \
  --role-name "${EC2_ROLE_NAME}" >/dev/null 2>&1 || true
aws iam delete-instance-profile --instance-profile-name "${EC2_INSTANCE_PROFILE_NAME}" >/dev/null 2>&1 || true
aws iam delete-role --role-name "${EC2_ROLE_NAME}" >/dev/null 2>&1 || true

grep -vE '^(IAM_ROLE_ARN)=' "$VARIABLES_FILE" > "$VARIABLES_FILE.tmp" || true
mv "$VARIABLES_FILE.tmp" "$VARIABLES_FILE"

echo "✅ IAM cleanup completed."
