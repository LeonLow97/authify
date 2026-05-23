#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

aws ssm delete-parameter --name "/authify/rds/db-name" >/dev/null 2>&1 || true
aws ssm delete-parameter --name "/authify/rds/endpoint" >/dev/null 2>&1 || true
aws ssm delete-parameter --name "/authify/rds/master-username" >/dev/null 2>&1 || true
aws ssm delete-parameter --name "/authify/rds/user" >/dev/null 2>&1 || true
aws ssm delete-parameter --name "/authify/rds/master-password" >/dev/null 2>&1 || true
aws ssm delete-parameter --name "/authify/rds/authify-user-password" >/dev/null 2>&1 || true
aws ssm delete-parameter --name "/authify/s3/bucket/schema" >/dev/null 2>&1 || true
aws ssm delete-parameter --name "/authify/s3/bucket/pem" >/dev/null 2>&1 || true
aws ssm delete-parameter --name "/authify/elasticache/endpoint" >/dev/null 2>&1 || true
aws ssm delete-parameter --name "/authify/elasticache/password" >/dev/null 2>&1 || true
aws ssm delete-parameter --name "/authify/auth/jwt-secret" >/dev/null 2>&1 || true
aws ssm delete-parameter --name "/authify/auth/jwt-domain" >/dev/null 2>&1 || true

echo "✅ SSM cleanup completed."
