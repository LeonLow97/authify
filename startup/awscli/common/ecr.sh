#!/bin/bash

source .env

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com >/dev/null 2>&1

aws ecr create-repository --repository-name $ECR_REPOSITORY_NAME --region $REGION >/dev/null 2>&1
aws ecr describe-repositories --region $REGION | grep $ECR_REPOSITORY_NAME

cd $API_GATEWAY_DIR
docker build -f Dockerfile --platform linux/amd64 -t $ECR_API_GATEWAY_IMAGE_NAME .
docker tag $ECR_API_GATEWAY_IMAGE_NAME $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPOSITORY_NAME:$ECR_API_GATEWAY_IMAGE_TAG
docker push $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPOSITORY_NAME:$ECR_API_GATEWAY_IMAGE_TAG >/dev/null 2>&1

cd $AUTH_SERVICE_DIR
docker build -f Dockerfile --platform linux/amd64 -t $ECR_AUTHENTICATION_SERVICE_IMAGE_NAME .
docker tag $ECR_AUTHENTICATION_SERVICE_IMAGE_NAME $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPOSITORY_NAME:$ECR_AUTHENTICATION_SERVICE_IMAGE_TAG
docker push $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPOSITORY_NAME:$ECR_AUTHENTICATION_SERVICE_IMAGE_TAG >/dev/null 2>&1
