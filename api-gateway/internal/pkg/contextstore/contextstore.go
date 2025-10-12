package contextstore

import (
	"fmt"
	"log"

	"github.com/gin-gonic/gin"
	"google.golang.org/grpc/metadata"
)

type contextKeyInt int

const (
	contextKeyGRPCMetadata contextKeyInt = iota
)

func InjectGRPCMetadataIntoContext(c *gin.Context, gprcCtx metadata.MD) {
	c.Set(contextKeyString(contextKeyGRPCMetadata), gprcCtx)
}

func GRPCMetadataFromContext(c *gin.Context) (metadata.MD, error) {
	mdCtx, exists := c.Get(contextKeyString(contextKeyGRPCMetadata))
	if !exists {
		log.Println("gRPC Metadata not found in context")
		return nil, ErrGRPCMetadataNotInContext
	}

	md, ok := mdCtx.(metadata.MD)
	if !ok {
		log.Println("gRPC Metadata in context is not of type metadata.MD")
		return nil, ErrGRPCMetadataIncorrectFormat
	}

	return md, nil
}

func contextKeyString(key contextKeyInt) string {
	return fmt.Sprintf("%v", key)
}
