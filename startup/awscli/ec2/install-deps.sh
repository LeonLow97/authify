#!/bin/bash
set -e  # Exit if any command fails

# Update system and install Docker
yum update -y
yum install -y docker
systemctl start docker
systemctl enable docker

# Add EC2 user to Docker group (avoids permission issues)
usermod -aG docker ims-ec2
