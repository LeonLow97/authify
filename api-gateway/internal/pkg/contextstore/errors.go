package contextstore

import "errors"

var (
	ErrGRPCMetadataNotInContext    = errors.New("grpc metadata not in context")
	ErrGRPCMetadataIncorrectFormat = errors.New("grpc metadata incorrect format")
)
