#!/bin/bash

source variables.txt

# Set variables
USER="ec2-user"
DOCKER_IMAGE=931100716322.dkr.ecr.ap-southeast-1.amazonaws.com/ims-repository:api-gateway-latest

# Step 1: Copy the EC2 key to Bastion host
echo "🔁 Copying $EC2_API_GATEWAY_KEY_NAME_AZ1.pem to Bastion ($BASTION_PUBLIC_IP_AZ1)..."
scp -i "$EC2_BASTION_HOST_KEY_NAME_AZ1.pem" -o StrictHostKeyChecking=no "$EC2_API_GATEWAY_KEY_NAME_AZ1.pem" "$USER@$BASTION_PUBLIC_IP_AZ1:~"
echo "🔁 Copying $EC2_API_GATEWAY_KEY_NAME_AZ2.pem to Bastion ($BASTION_PUBLIC_IP_AZ2)..."
scp -i "$EC2_BASTION_HOST_KEY_NAME_AZ2.pem" -o StrictHostKeyChecking=no "$EC2_API_GATEWAY_KEY_NAME_AZ2.pem" "$USER@$BASTION_PUBLIC_IP_AZ2:~"

# Step 2: SSH into Bastion, then EC2 A, then run Docker
echo "🔁 Connecting to Bastion Host EC2 AZ1 ($API_GATEWAY_PRIVATE_IP_AZ1) and starting Docker container..."
ssh -i "$EC2_BASTION_HOST_KEY_NAME_AZ1.pem" -o StrictHostKeyChecking=no "$USER@$BASTION_PUBLIC_IP_AZ1" << EOF
  ssh -o StrictHostKeyChecking=no -i $EC2_API_GATEWAY_KEY_NAME_AZ1.pem $USER@$API_GATEWAY_PRIVATE_IP_AZ1 << INNER_EOF
    echo "✅ Connected to API Gateway EC2 AZ1: $API_GATEWAY_PRIVATE_IP_AZ1"
    echo "🐳 Running Docker container with AUTH_SERVICE_NAME=$AUTH_SERVICE_PRIVATE_IP_AZ1"
    aws ecr get-login-password --region ap-southeast-1 | sudo docker login --username AWS --password-stdin 931100716322.dkr.ecr.ap-southeast-1.amazonaws.com
    sudo docker run -d --name api-gateway -p 8080:8080 -e MODE=production -e AUTH_SERVICE_NAME=$AUTH_SERVICE_PRIVATE_IP_AZ1 $DOCKER_IMAGE
INNER_EOF
EOF
echo "🔁 Connecting to Bastion Host EC2 AZ2 ($API_GATEWAY_PRIVATE_IP_AZ2) and starting Docker container..."
ssh -i "$EC2_BASTION_HOST_KEY_NAME_AZ2.pem" -o StrictHostKeyChecking=no "$USER@$BASTION_PUBLIC_IP_AZ2" << EOF
  ssh -o StrictHostKeyChecking=no -i $EC2_API_GATEWAY_KEY_NAME_AZ2.pem $USER@$API_GATEWAY_PRIVATE_IP_AZ2 << INNER_EOF
    echo "✅ Connected to API Gateway EC2 AZ2: $API_GATEWAY_PRIVATE_IP_AZ2"
    echo "🐳 Running Docker container with AUTH_SERVICE_NAME=$AUTH_SERVICE_PRIVATE_IP_AZ2"
    aws ecr get-login-password --region ap-southeast-1 | sudo docker login --username AWS --password-stdin 931100716322.dkr.ecr.ap-southeast-1.amazonaws.com
    sudo docker run -d --name api-gateway -p 8080:8080 -e MODE=production -e AUTH_SERVICE_NAME=$AUTH_SERVICE_PRIVATE_IP_AZ2 $DOCKER_IMAGE
INNER_EOF
EOF
