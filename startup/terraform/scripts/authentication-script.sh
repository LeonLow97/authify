#!/bin/bash
set -e  # Exit if any command fails

# Update system and install Docker
sudo yum update -y
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker

# Add EC2 user to Docker group (avoids permission issues)
sudo usermod -aG docker ec2-user

# Fetch parameters from SSM Parameter Store
RDS_ENDPOINT=$(aws ssm get-parameter --name "/ims/db/hostname" --query "Parameter.Value" --output text --region ap-southeast-1)
DB_MASTER_USERNAME=$(aws ssm get-parameter --name "/ims/db/master-username" --query "Parameter.Value" --output text --region ap-southeast-1)
DB_MASTER_PASSWORD=$(aws ssm get-parameter --name "/ims/db/master-password" --with-decryption --query "Parameter.Value" --output text --region ap-southeast-1)
IMS_DB_NAME=$(aws ssm get-parameter --name "/ims/db/db-name" --query "Parameter.Value" --output text --region ap-southeast-1)

# Authentication with Docker Registry, IMS is using AWS Elastic Container Registry (ECR)
aws ecr get-login-password --region ap-southeast-1 | sudo docker login --username AWS --password-stdin 931100716322.dkr.ecr.ap-southeast-1.amazonaws.com

# Pull Docker image after authentication
sudo docker pull 931100716322.dkr.ecr.ap-southeast-1.amazonaws.com/ims-repository:authentication-service-latest

# Run Docker container and pass environment variables
sudo docker run -d \
	--name authentication-service \
	-p 50051:50051 \
	-e MODE=production \
	-e POSTGRES_HOST=$RDS_ENDPOINT \
	-e POSTGRES_USER=$DB_MASTER_USERNAME \
	-e POSTGRES_PASSWORD=$DB_MASTER_PASSWORD \
	-e POSTGRES_DB=$IMS_DB_NAME \
	931100716322.dkr.ecr.ap-southeast-1.amazonaws.com/ims-repository:authentication-service-latest
