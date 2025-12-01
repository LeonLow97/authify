#!/bin/bash

source .env

# Remove local Docker images
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com >/dev/null 2>&1
echo "Removing images..."
docker rmi $ECR_AUTHENTICATION_SERVICE_IMAGE_NAME $ECR_API_GATEWAY_IMAGE_NAME

# Delete the ECR repository (if no longer needed)
echo "Deleting repository..."
aws ecr delete-repository --repository-name $ECR_REPOSITORY_NAME --region $REGION --force >/dev/null 2>&1
