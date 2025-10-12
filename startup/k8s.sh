# pull registry:2 image from docker hub and start a container at port 5000
echo "Step 1: Pulling registry:2 image from Docker Hub and starting container at port 5050!"
docker run -d -p 5050:5000 --name registry registry:2

echo "\nStep 2: Checking repositories in Docker Registry, should see {"repositories":[]} because it is a fresh Docker Registry with no images"
curl -X GET http://localhost:5050/v2/_catalog

echo "\nStep 3: Pushing microservices images to local Docker Registry"
echo "\tBuilding API Gateway image and pushing to Docker Registry..."
cd ../api-gateway 
docker build -t ims-api-gateway .
docker tag ims-api-gateway localhost:5050/ims-api-gateway:latest
docker push localhost:5050/ims-api-gateway:latest

echo "\tBuilding Authentication Microservice image and pushing to Docker Registry..."
cd ../authentication-service
docker build -t ims-authentication .
docker tag ims-authentication localhost:5050/ims-authentication:latest
docker push localhost:5050/ims-authentication:latest

echo "\nStep 4: Checking repositories in Docker Registry, should see 4 images tagged with 'ims'"
curl -X GET http://localhost:5050/v2/_catalog

echo "\nStep 5: Creating namespace for inventory-management-system in k8s cluster..."
kubectl create namespace inventory-management-system
kubectl get namespaces

echo "\nStep 6: Setting namespace context globally in k8s"
kubectl config set-context --current --namespace=inventory-management-system

echo "\nStep 7 Checking current namespace context, ensure it is inventory-management-system"
kubectl config view --minify | grep namespace:

echo "\nStep 8: Adding ingress controller"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
