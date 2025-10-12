go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.28
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.2
export PATH="$PATH:$(go env GOPATH)/bin"

echo "init api-gateway service"
cd ../api-gateway
gofmt -w .
go mod edit -go 1.23
go mod tidy
grep -rnw './' -e 'fmt.Println'
protoc --go_out=. --go-grpc_out=. proto/authentication.proto
protoc --go_out=. --go-grpc_out=. proto/users.proto
protoc --go_out=. --go-grpc_out=. proto/inventory.proto
protoc --go_out=. --go-grpc_out=. proto/order.proto

echo "init authentication microservice"
cd ../authentication-service
gofmt -w .
go mod edit -go 1.23
go mod tidy
grep -rnw './' -e 'fmt.Println'
protoc --go_out=. --go-grpc_out=. proto/authentication.proto
protoc --go_out=. --go-grpc_out=. proto/users.proto
