#!/bin/bash

source variables.txt
source .env

USER="ec2-user"

ssh -i "$EC2_BASTION_HOST_KEY_NAME_AZ1.pem" -o StrictHostKeyChecking=no "$USER@$BASTION_PUBLIC_IP_AZ1" << EOF
	echo "Creating $IMS_DB_NAME database..."
	PGPASSWORD=$DB_MASTER_PASSWORD psql -h $RDS_ENDPOINT -U $DB_MASTER_USERNAME -d postgres -c "CREATE DATABASE $IMS_DB_NAME;" || { echo "❌ Failed to create database $IMS_DB_NAME"; exit 1; }
	echo "✅ Successfully created database $IMS_DB_NAME."

	# Grant privileges to master user and set default privileges
	echo "Granting privileges to $DB_MASTER_USERNAME on $IMS_DB_NAME..."
	PGPASSWORD=$DB_MASTER_PASSWORD psql -h $RDS_ENDPOINT -U $DB_MASTER_USERNAME -d $IMS_DB_NAME -c "
		-- Grant privileges on $IMS_DB_NAME to the master user
		GRANT ALL PRIVILEGES ON DATABASE $IMS_DB_NAME TO $DB_MASTER_USERNAME;
		GRANT ALL PRIVILEGES ON DATABASE $IMS_DB_NAME TO $DB_MASTER_USERNAME;

		-- Grant privileges on public schema to $DB_MASTER_USERNAME
		GRANT ALL PRIVILEGES ON SCHEMA public TO $DB_MASTER_USERNAME;

		-- Grant SELECT, INSERT, UPDATE, DELETE on all tables in the public schema
		GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO $DB_MASTER_USERNAME;

		-- Set default privileges for new tables and sequences in the public schema
		ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_MASTER_USERNAME;
		ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_MASTER_USERNAME;
	" || { echo "❌ Failed to grant privileges to $DB_MASTER_USERNAME"; exit 1; }
	echo "✅ Successfully granted privileges to $DB_MASTER_USERNAME."
EOF

scp -i "$EC2_BASTION_HOST_KEY_NAME_AZ1.pem" "./init-db/init-authentication-db.sql" "$USER@$BASTION_PUBLIC_IP_AZ1:~"
ssh -i "$EC2_BASTION_HOST_KEY_NAME_AZ1.pem" -o StrictHostKeyChecking=no "$USER@$BASTION_PUBLIC_IP_AZ1" << EOF
  # Run the SQL file using psql (correct path to the file on Bastion host)
  PGPASSWORD=$DB_MASTER_PASSWORD psql -h $RDS_ENDPOINT -U $DB_MASTER_USERNAME -d $IMS_DB_NAME -f ~/init-authentication-db.sql || { echo "❌ Failed to execute SQL script"; exit 1; }
  echo "✅ Successfully created tables in Authentication Postgres Database."
EOF
