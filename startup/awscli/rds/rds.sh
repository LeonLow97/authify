#!/bin/bash

# ============================
# Configuration
# ============================
RDS_INSTANCE_IDENTIFIER="authify"
DB_INSTANCE_CLASS="db.t3.micro"
ENGINE="postgres"

aws rds create-db-instance \
    --db-instance-identifier $RDS_INSTANCE_IDENTIFIER \
    --db-instance-class $DB_INSTANCE_CLASS \
    --engine $ENGINE \
    --allocated-storage 5 \
    --master-username authify \
    --master-user-password authify9876 \
    --no-multi-az \
    --backup-retention-period 0 \
    --publicly-accessible >/dev/null 2>&1
echo "RDS instance RDS_INSTANCE_IDENTIFIER=$RDS_INSTANCE_IDENTIFIER created..."

aws rds wait db-instance-available --db-instance-identifier $RDS_INSTANCE_IDENTIFIER
echo "RDS instance $RDS_INSTANCE_IDENTIFIER is now available."

RDS_SG_ID=$(aws rds describe-db-instances \
    --db-instance-identifier $RDS_INSTANCE_IDENTIFIER \
    --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text)
echo "RDS_SG_ID=$RDS_SG_ID"

PUBLIC_IP=$(curl -s https://checkip.amazonaws.com)
echo "PUBLIC_IP=$PUBLIC_IP"

echo "Authorizing inbound access to RDS instance from IP $PUBLIC_IP..."
aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG_ID \
  --protocol tcp \
  --port 5432 \
  --cidr $PUBLIC_IP/32 \
  --region $REGION \
  >/dev/null 2>&1

echo "Retrieving RDS instance information..."
RDS_INSTANCE_INFO=$(aws rds describe-db-instances \
  --db-instance-identifier "$RDS_INSTANCE_IDENTIFIER" \
  --output json)
RDS_ENDPOINT=$(echo "$RDS_INSTANCE_INFO" | jq -r '.DBInstances[0].Endpoint.Address')
MASTER_USERNAME=$(echo "$RDS_INSTANCE_INFO" | jq -r '.DBInstances[0].MasterUsername')
echo "RDS_ENDPOINT=$RDS_ENDPOINT"
echo "MASTER_USERNAME=$MASTER_USERNAME"

PGPASSWORD=$MASTER_PASSWORD psql -h $RDS_ENDPOINT -U $MASTER_USERNAME -d postgres -c "CREATE DATABASE IF NOT EXISTS authify_users_db;"
echo "Created ims-db database"