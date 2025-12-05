#!/bin/bash
set -e  # Exit if any command fails

# Update system and install Docker
sudo yum update -y
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker

# Add EC2 user to Docker group (avoids permission issues)
sudo usermod -aG docker ec2-user

# Set variables
USER="ec2-user"
DOCKER_IMAGE=931100716322.dkr.ecr.ap-southeast-1.amazonaws.com/ims-repository:api-gateway-latest
AUTH_SERVICE_IP=${auth_service_ip}

echo "AUTH_SERVICE_IP=$AUTH_SERVICE_IP"

aws ecr get-login-password --region ap-southeast-1 | sudo docker login --username AWS --password-stdin 931100716322.dkr.ecr.ap-southeast-1.amazonaws.com
sudo docker run -d --name api-gateway -p 8080:8080 -e MODE=production -e AUTH_SERVICE_NAME=$AUTH_SERVICE_IP $DOCKER_IMAGE
