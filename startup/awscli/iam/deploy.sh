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

if aws iam get-role --role-name "${EC2_ROLE_NAME}" >/dev/null 2>&1; then
  IAM_ROLE_ARN="$(aws iam get-role --role-name "${EC2_ROLE_NAME}" --query 'Role.Arn' --output text)"
  echo "IAM role $EC2_ROLE_NAME already exists, skipping creation."
else
  echo "Creating IAM role $EC2_ROLE_NAME ..."
  IAM_ROLE_ARN="$(aws iam create-role \
    --role-name "${EC2_ROLE_NAME}" \
    --assume-role-policy-document '{
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Allow",
        "Principal": { "Service": "ec2.amazonaws.com" },
        "Action": "sts:AssumeRole"
      }]
    }' \
    --query 'Role.Arn' \
    --output text)"
fi

for policy in "${POLICIES[@]}"; do
  ATTACHED_POLICY="$(aws iam list-attached-role-policies \
    --role-name "${EC2_ROLE_NAME}" \
    --query "AttachedPolicies[?PolicyArn=='${policy}'].PolicyArn | [0]" \
    --output text 2>/dev/null || true)"
  if [[ "$ATTACHED_POLICY" != "$policy" ]]; then
    aws iam attach-role-policy --role-name "${EC2_ROLE_NAME}" --policy-arn "${policy}" >/dev/null
  fi
done

if ! aws iam get-instance-profile --instance-profile-name "${EC2_INSTANCE_PROFILE_NAME}" >/dev/null 2>&1; then
  echo "Creating instance profile $EC2_INSTANCE_PROFILE_NAME ..."
  aws iam create-instance-profile --instance-profile-name "${EC2_INSTANCE_PROFILE_NAME}" >/dev/null
fi

aws iam wait instance-profile-exists --instance-profile-name "${EC2_INSTANCE_PROFILE_NAME}"

INSTANCE_PROFILE_ROLE="$(aws iam get-instance-profile \
  --instance-profile-name "${EC2_INSTANCE_PROFILE_NAME}" \
  --query "InstanceProfile.Roles[?RoleName=='${EC2_ROLE_NAME}'].RoleName | [0]" \
  --output text 2>/dev/null || true)"
if [[ "$INSTANCE_PROFILE_ROLE" != "$EC2_ROLE_NAME" ]]; then
  aws iam add-role-to-instance-profile \
    --instance-profile-name "${EC2_INSTANCE_PROFILE_NAME}" \
    --role-name "${EC2_ROLE_NAME}" >/dev/null
fi

grep -vE '^(IAM_ROLE_ARN)=' "$VARIABLES_FILE" > "$VARIABLES_FILE.tmp" || true
{
  cat "$VARIABLES_FILE.tmp"
  echo "IAM_ROLE_ARN=$IAM_ROLE_ARN"
} > "$VARIABLES_FILE"
rm -f "$VARIABLES_FILE.tmp"

echo "✅ IAM role and instance profile ready."
