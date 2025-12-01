#!/bin/bash
set -e  # Exit if any command fails

# Update system and install Docker
sudo yum update -y
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker

# Add EC2 user to Docker group (avoids permission issues)
sudo usermod -aG docker ec2-user
