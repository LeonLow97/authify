#!/bin/bash

source .env

# Set up RDS PostgreSQL
# Create PostgreSQL RDS Instance for Authentication Microservice
aws rds create-db-instance \
    --db-instance-identifier authentication-postgres \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --allocated-storage 5 \
    --master-username authentication_postgres \
    --master-user-password verysecurepassword \
    --no-multi-az \
    --backup-retention-period 0 \
    --publicly-accessible >/dev/null 2>&1
echo "RDS_INSTANCE_IDENTIFIER=$RDS_INSTANCE_IDENTIFIER"

# Wait for the DB Instance to be in 'available' state
aws rds wait db-instance-available --db-instance-identifier $RDS_INSTANCE_IDENTIFIER
echo "# Waiting for PostgreSQL RDS to be in available state..."

# Retrieve the DB Instance's security group ID
RDS_SG_ID=$(aws rds describe-db-instances \
    --db-instance-identifier $RDS_INSTANCE_IDENTIFIER \
    --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text)

# Get the public IP address of your machine to connect with PostgreSQL RDS on your machine
PUBLIC_IP=$(curl -s https://checkip.amazonaws.com)

# Add the public IP address to inbound role of Security Group of PostgreSQL RDS Instance
aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG_ID \
  --protocol tcp \
  --port 5432 \
  --cidr $PUBLIC_IP/32 \
  --region $REGION \
  >/dev/null 2>&1

  # Define RDS PostgreSQL variables
RDS_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $RDS_INSTANCE_IDENTIFIER --query "DBInstances[0].Endpoint.Address" --output text)
MASTER_USERNAME=$(aws rds describe-db-instances --db-instance-identifier $RDS_INSTANCE_IDENTIFIER --query "DBInstances[0].MasterUsername" --output text)

# Create imsdb database
PGPASSWORD=$MASTER_PASSWORD psql -h $RDS_ENDPOINT -U $MASTER_USERNAME -d postgres -c "CREATE DATABASE imsdb;"
echo "Created ims-db database"

# Create 'authentication_postgres' user, grant necessary privileges on the imsdb database and public schema, 
# set default privileges for new tables/sequences
PGPASSWORD=$MASTER_PASSWORD psql -h $RDS_ENDPOINT -U $MASTER_USERNAME -d imsdb -c "
  -- Grant privileges on imsdb to the master and authentication_postgres user
  GRANT ALL PRIVILEGES ON DATABASE imsdb TO $MASTER_USERNAME;
  GRANT ALL PRIVILEGES ON DATABASE imsdb TO $MASTER_USERNAME;

  -- Grant privileges on public schema to authentication_postgres
  GRANT ALL PRIVILEGES ON SCHEMA public TO $MASTER_USERNAME;

  -- Grant SELECT, INSERT, UPDATE, DELETE on all tables in the public schema
  GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO $MASTER_USERNAME;

  -- Set default privileges for new tables and sequences in the public schema
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $MASTER_USERNAME;
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $MASTER_USERNAME;
"
echo "Granted necessary privileges to $MASTER_USERNAME"

# Run SQL script to create tables for authentication microservice
# PGPASSWORD=$MASTER_PASSWORD psql -h $RDS_ENDPOINT -U $MASTER_USERNAME -d imsdb -f $AuthMicroservicePGTablesInitFilePath
