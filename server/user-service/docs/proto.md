## Command to Compile `.proto` files into Go Code

```
go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.28
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.2
export PATH="$PATH:$(go env GOPATH)/bin"
protoc --go_out=. --go-grpc_out=. proto/authentication.proto
protoc --go_out=. --go-grpc_out=. proto/users.proto
```
