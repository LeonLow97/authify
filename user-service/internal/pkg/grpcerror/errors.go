package grpcerror

import (
	"log"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// Predefined Errors
var (
	ECEmailAlreadyExists = &CustomError{codes.AlreadyExists, "Email already exists"}

	// Generic Errors
	ECUnauthorized        = &CustomError{codes.Unauthenticated, "Unauthenticated"}
	ECInternalServerError = &CustomError{codes.Internal, "Internal Server Error"}
)

// CustomError represents a structured error with a gRPC Code
type CustomError struct {
	Code    codes.Code
	Message string
}

// Error implements the error interface
func (e *CustomError) Error() string {
	return e.Message
}

// GRPCError converts a CustomError into a gRPC status error
func (e *CustomError) GRPCError(err error) error {
	log.Printf("gRPC Error: %s | Original Error: %v", e.Message, err)
	return status.Errorf(e.Code, "%s", e.Message)
}
