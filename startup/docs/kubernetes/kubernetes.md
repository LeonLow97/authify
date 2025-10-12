# Kubernetes

- [Kubernetes Overview](#kubernetes-overview)
  - [What is Kubernetes?](#what-is-kubernetes)
  - [Why use Kubernetes in Microservices Architecture?](#why-use-kubernetes-in-microservice-architecture)
- [Kubernetes Resources / Objects used in IMS](#kubernetes-resources--objects-used-in-ims)

# Kubernetes Overview

## What is Kubernetes?

Kubernetes (k8s) is an open-source system and **container orchestration platform** for automating the deployment, scaling and management of containerized applications.

## Why use Kubernetes in Microservice Architecture?

- **Microservices Deployment**: Facilitates the deployment of multiple microservices independently, improving agility.
- **Resource Efficiency**: Optimizes resource usage by packing multiple containers onto fewer machines.
- **Service Discovery**: Automatically manages the discovery and routing of service requests.
- **Environment Consistency**: Ensures consistent environments across development, testing and production. This eliminates the "it works on my machine" issues, as all environments are consistent.
- **Automated Rollouts and Rollbacks**: Supports seamless updates and quick rollbacks if issues arise. For instance, when deploying a new feature in an application, Kubernetes can gradually roll out the update to a small percentage of users. If issues are detected, it can automatically roll back to the previous version, minimizing downtime and impact on users.
- **Infrastructure Abstraction**: Abstracts the underlying infrastructure, allowing developers to focus on application code rather than deployment complexities. Developers do not have to worry about underlying servers, networking or storage, Kubernetes handles these complexities.

# Kubernetes Resources / Objects used in IMS

## Ingress

Ingress is a Kubernetes resource that manages **external access** to services within a cluster, primarily HTTP and HTTPS traffic. It can also handle other protocols such as TCP/UDP, WebSocket and gRPC. Ingress provides a way to define rules for routing external requests to the appropriate services based on host names and paths.

## Ingress Resource in IMS

- The Ingress resource is a k8s object that **defines the rules for routing incoming traffic**.
- It specifies how to **map external URLs to internal services**, allowing traffic to reach the right service based on request parameters.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ims-ingress-resource
  namespace: inventory-management-system
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - host: localhost # Docker Desktop (Kubernetes)
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api-gateway-clusterip
                port:
                  number: 80
```

- In the Ingress Resource configuration file for IMS, requests to `localhost` are routed to `api-gateway-clusterip` service on port 80.
- `annotations`: this is a way to attach metadata to the Ingress.
  - `nginx.ingress.kubernetes.io/rewrite-target: /` specifies an NGINX specific annotation. This annotation tells the NGINX Ingress Controller to rewrite the URL path of incoming requests to `/`, regardless of the original path.
- `ingressClassName`: this specifies which Ingress Controller to use. Here, it indicates that the `nginx` Ingress Controller should manage this Ingress resource.
  - This is needed because we can have multiple Ingress Controllers in the same Kubernetes cluster. Each Ingress Controller can be associated with different Ingress resources through the `ingressClassName` field.
- `rules`: contains the rules for routing external traffic.
  - `host`: this indicates that the rule applies to requests coming to `localhost`. This is often used in development environments, such as Docker Desktop.
  - `http`: specifies that this rule is for HTTP traffic.
    - `paths`: lists the path to match
      - `path`: Here, it matches all paths (`/`), indicating that any request sent to `localhost` will be routed according to this rule.
      - `pathType`: `Prefix` means that any request path that starts with `/` will match this rule.
      - `backend`: defines the service to which the traffic should be routed:
        - `name`: the name of the service is `api-gateway-clusterip`, which is likely a `ClusterIP` service.
        - `port`: specifies that traffic should be routed to port 80 of the specified service.

## Ingress Controller in IMS

- An Ingress Controller is a component that **implements the Ingress resource's rules and manages the actual traffic routing**.
- It listens for changes to Ingress resources and updates its routing configuration accordingly.
- There are various Ingress Controllers available, including:
  - **NGINX Ingress Controller**: One of the most commonly used controllers, based on NGINX.
  - **Traefik**: A dynamic reverse proxy and load balancer.
  - **HAProxy Ingress**: Based on HAProxy, known for high performance.
- The Ingress Controller runs as a Pod in the cluster and configures an external load balancer or proxy to manage the incoming traffic based on the defined Ingress rules.
  - The Ingress Controller routes incoming requests to the backend services, this includes load balancing traffic across multiple instances of a service.

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
```

- In IMS, we are deploying the **NGINX Ingress Controller** to the Kubernetes Cluster (as shown in the command above).
- When the command is ran, the YAML file is pulled from the official NGINX Ingress GitHub repository and `kubectl apply -f` will deploy various Kubernetes resources needed for the NGINX Ingress Controller.
- This controller will handle incoming HTTP and HTTPS requests and route them to the appropriate services based on defined Ingress rules in Ingress resource.
