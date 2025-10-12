# API Gateway

The API Gateway exposes a set of API Endpoints via REST and redirects the request to the respective microservice via gRPC communication.

# Architecture

# Features

- **Request Validation**

# API Endpoints

| Method |    Endpoint    | Description                                                                                                                          |
| :----: | :------------: | ------------------------------------------------------------------------------------------------------------------------------------ |
|  GET   | `/healthcheck` | Returns HTTP Status `200 OK` when application is running and in healthy status. Mainly for Kubernetes liveness and readiness probes. |
