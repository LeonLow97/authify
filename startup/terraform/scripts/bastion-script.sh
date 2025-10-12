#!/bin/bash

sudo dnf install -y postgresql15

USER="ec2-user"
S3_URI="s3://ims-bucket-jiewei/sql-uploads/init-authentication-db.sql"
LOCAL_PATH="/home/ec2-user/init-authentication-db.sql"

# Fetching Bastion host IP and key name dynamically
BASTION_PUBLIC_IP_AZ1=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=BastionHost" --query "Reservations[0].Instances[0].PublicIpAddress" --output text)
EC2_BASTION_HOST_KEY_NAME_AZ1=IMS_BASTION_AZ1

# Fetching RDS configuration from AWS SSM
RDS_ENDPOINT=$(aws ssm get-parameters --names "/ims/db/hostname" --query "Parameters[0].Value" --output text)
DB_MASTER_USERNAME=$(aws ssm get-parameters --names "/ims/db/master-username" --query "Parameters[0].Value" --output text)
DB_MASTER_PASSWORD=$(aws ssm get-parameters --names "/ims/db/master-password" --with-decryption --query "Parameters[0].Value" --output text)
IMS_DB_NAME=$(aws ssm get-parameters --names "/ims/db/db-name" --query "Parameters[0].Value" --output text)

echo "RDS_ENDPOINT=$RDS_ENDPOINT"
echo "DB_MASTER_USERNAME=$DB_MASTER_USERNAME"
echo "DB_MASTER_PASSWORD=$DB_MASTER_PASSWORD"
echo "IMS_DB_NAME=$IMS_DB_NAME"

# Install PostgreSQL client
sudo dnf install -y postgresql15

# Create imsdb database
echo "Creating $IMS_DB_NAME database..."
PGPASSWORD=$DB_MASTER_PASSWORD psql -h $RDS_ENDPOINT -U $DB_MASTER_USERNAME -d postgres -c "CREATE DATABASE $IMS_DB_NAME;" || { echo "❌ Failed to create database $IMS_DB_NAME"; }
echo "✅ Successfully created database $IMS_DB_NAME."

# Grant privileges to the master user
echo "Granting privileges to $DB_MASTER_USERNAME on $IMS_DB_NAME..."
PGPASSWORD=$DB_MASTER_PASSWORD psql -h $RDS_ENDPOINT -U $DB_MASTER_USERNAME -d $IMS_DB_NAME -c "
  -- Grant privileges on $IMS_DB_NAME to the master user
  GRANT ALL PRIVILEGES ON DATABASE $IMS_DB_NAME TO $DB_MASTER_USERNAME;

  -- Grant privileges on public schema to $DB_MASTER_USERNAME
  GRANT ALL PRIVILEGES ON SCHEMA public TO $DB_MASTER_USERNAME;

  -- Grant SELECT, INSERT, UPDATE, DELETE on all tables in the public schema
  GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO $DB_MASTER_USERNAME;

  -- Set default privileges for new tables and sequences in the public schema
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_MASTER_USERNAME;
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_MASTER_USERNAME;
" || { echo "❌ Failed to grant privileges to $DB_MASTER_USERNAME"; }
echo "✅ Successfully granted privileges to $DB_MASTER_USERNAME."

echo "Downloading SQL script from: $S3_URI"
if aws s3 cp "$S3_URI" "$LOCAL_PATH" --region ap-southeast-1; then
  echo "✅ Successfully downloaded SQL script to $LOCAL_PATH"
else
  echo "❌ Failed to download SQL script from S3. Exiting."
fi

echo "Running SQL script to initialize Authentication DB..."
if PGPASSWORD="$DB_MASTER_PASSWORD" psql -h "$RDS_ENDPOINT" -U "$DB_MASTER_USERNAME" -d "$IMS_DB_NAME" -f "$LOCAL_PATH"; then
  echo "✅ Successfully executed SQL script on $IMS_DB_NAME"
else
  echo "❌ Failed to execute SQL script. Check database connectivity and credentials."
fi

echo "EC2 setup completed successfully."
