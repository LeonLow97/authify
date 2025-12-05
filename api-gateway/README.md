# API Gateway

The API Gateway exposes a set of API Endpoints via REST and redirects the request to the respective microservice via gRPC communication.

# Architecture

# API Endpoints

| Method |      Endpoint      | Description                                                                                                            |
| :----: | :----------------: | ---------------------------------------------------------------------------------------------------------------------- |
|  GET   | `/health/liveness` | Returns HTTP Status `200 OK` when application is running and in healthy status. Mainly for Kubernetes liveness probes. |

# Synchronize gRPC

```
go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.28
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.2
export PATH="$PATH:$(go env GOPATH)/bin"
protoc --go_out=. --go-grpc_out=. proto/users.proto
```
