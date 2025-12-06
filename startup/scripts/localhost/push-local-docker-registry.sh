#!/bin/bash

# Stop and remove registry if running
docker stop registry 2>/dev/null || true
docker rm registry 2>/dev/null || true

ROOT_DIR="$(cd "$(dirname "$0")"/../.. && pwd)"
echo "ROOT_DIR is: $ROOT_DIR"

echo "Step 1: Pulling registry:2 image from Docker Hub and starting container at port 5050!\n"
docker run -d -p 5050:5000 --name registry registry:2

echo 'Step 2: Checking repositories in Docker Registry, should see {"repositories":[]} because it is a fresh Docker Registry with no images\n'
curl -X GET http://localhost:5050/v2/_catalog

echo "Step 3: Pushing microservices images to local Docker Registry\n"

echo "Building API Gateway image and pushing to Docker Registry...\n"
cd "$ROOT_DIR/api-gateway"
docker build -t authify-api-gateway .
docker tag authify-api-gateway localhost:5050/authify-api-gateway:latest
docker push localhost:5050/authify-api-gateway:latest

echo "Building User Microservice image and pushing to Docker Registry...\n"
cd "$ROOT_DIR/user-service"
docker build -t authify-user .
docker tag authify-user localhost:5050/authify-user:latest
docker push localhost:5050/authify-user:latest

echo "Step 4: Checking repositories in Docker Registry, should see 4 images tagged with 'authify'\n"
curl -X GET http://localhost:5050/v2/_catalog
