#!/bin/bash

source .env

# RDS Cleanup
if [ -n "$RDS_INSTANCE_IDENTIFIER" ]; then
  echo "Stopping and Deleting RDS Instance..."

  # Stop the RDS instance
  aws rds stop-db-instance --db-instance-identifier $RDS_INSTANCE_IDENTIFIER >/dev/null 2>&1

  # Delete the RDS instance
  aws rds delete-db-instance --db-instance-identifier $RDS_INSTANCE_IDENTIFIER --skip-final-snapshot >/dev/null 2>&1

  # Wait for the RDS instance to be deleted
  echo "Waiting for RDS instance to be deleted..."
  aws rds wait db-instance-deleted --db-instance-identifier $RDS_INSTANCE_IDENTIFIER
  echo "RDS Instance deleted successfully."
fi
