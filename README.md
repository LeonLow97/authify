# Authify

Authify is a production-ready authentication and authorization microservice designed for modern, scalable applications.

# Table of Contents

- [Authify](#authify)
- [Table of Contents](#table-of-contents)
- [Microservices Architecture](#microservices-architecture)
- [Project Setup](#project-setup)
  - [Localhost](#localhost)
    - [Docker](#docker)
    - [Kubernetes](#kubernetes)
- [AWS Deployment](#aws-deployment)
  - [AWS Elastic Beanstalk](#aws-elastic-beanstalk)

# Microservices Architecture

# Project Setup

There are multiple ways to start authify:

- Localhost
- Docker
- Local Kubernetes (Docker Desktop)
- AWS Elastic Beanstalk
- AWS EC2

Please ensure the following ports are available and not taken:

| Technology        | Port  |
| ----------------- | :---: |
| API Gateway       |  80   |
| User Microservice | 50051 |
| Redis             | 6379  |
| PostgreSQL        | 5432  |

## Localhost

### Docker

1. Navigate to the `server/project` directory:

```bash
cd ./server/project
```

2. Run `init.sh` to setup `.proto` files and install gRPC. These `.proto` files are compiled using `protoc` which is the protocol buffers compiler, to generate code in Golang that enables efficient serialization and deserialization in gRPC communication.

```bash
sh init.sh
```

3. Start the Docker containers by pulling images from Docker Hub registry, creating the containers and running them on localhost:

```bash
docker-compose up --build -d
```

OR (if using Makefile)

```bash
make build
```

### Kubernetes

1. Create directories for persistent volumes on your local machine for the following microservices: Authentication, Inventory and Order. The persistent volumes will be created in the user's home directory:

```bash
mkdir -p $(echo $HOME)/persistent_volume/inventory-mysql $(echo $HOME)/persistent_volume/order-postgres $(echo $HOME)/persistent_volume/authentication-postgres
```

2. Navigate to and open the Kubernetes Persistent Volume (PV) config file `persistent-volume.yml`

```bash
cd ./server/project/k8s/
vi persistent-volume.yml
```

3. Edit the `hostPath` for all 3 persistent volumes - `inventory-mysql`, `order-postgres`, `authentication-postgres`

- For my MacOS, the path is `/Users/leonlow`.
- For your machine, run `echo $HOME` to get your home directory path, and use the result to update the `hostPath`.

```bash
hostPath:
  path: /Users/leonlow/persistent_volume/inventory-mysql
```

4. Run the following bash script `k8s.sh`. The script automates the setup of a **local Docker Registry** (TODO: probably should use Docker Hub Registry) and pushes container images for the IMS microservices (API Gateway, Authentication, Order and Inventory) to it. Then, it configures a **Kubernetes namespace** (`inventory-management-system`), sets the context, and verifies the namespace switch. Finally, it **deploys an NGINX Ingress Controller** to manage external access to the microservices within the Kubernetes Cluster.

```bash
sh k8s.sh
```

5. Deploy all Kubernetes Configuration files (YAML) which includes Ingress, ClusterIP, Deployments, Services, ConfigMaps, Secrets, StatefulSets, StorageClass.

```bash
kubectl apply -f ./k8s
```

Might throw an error because ingress resources takes a while to start as Kubernetes takes time to schedule and start the NGINX Ingress Controller pods. Wait for a few minutes and run the following command:

```sh
kubectl apply -f ./k8s/ingress-resource.yml
```

6. Ensure all pods are up and running:

```
kubectl get pods
```

7. Call the HealthCheck endpoint on API Gateway to ensure service is up and running:

```sh
curl http://localhost:80/healthcheck
```

# AWS Deployment

## AWS Elastic Beanstalk

- For deployment steps, check out [IMS AWS Elastic Beanstalk Deployment Guide](./server/project/docs/AWS/aws-elastic-beanstalk/deployment.md)
- For deployment steps, check out [IMS AWS EC2 Deployment Guide](./server/project/docs/AWS/aws-ec2/deployment.md)
