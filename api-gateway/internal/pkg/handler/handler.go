package handler

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type Handler struct {
	validator *validator.Validate
}

func NewHandler() Handler {
	return Handler{
		validator: validatorInstance(),
	}
}

func (h *Handler) RespondGrpcError(c *gin.Context, err error) codes.Code {
	st, ok := status.FromError(err)
	if !ok {
		log.Println("[gRPC Error] Non-gRPC error:", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Internal server error"})
		return codes.Unknown
	}

	message := st.Message()
	code := st.Code()

	switch code {

	// Client errors
	case codes.InvalidArgument:
		c.JSON(http.StatusBadRequest, gin.H{"error": message})
	case codes.Unauthenticated:
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
	case codes.PermissionDenied:
		c.JSON(http.StatusForbidden, gin.H{"error": message})
	case codes.NotFound:
		c.JSON(http.StatusNotFound, gin.H{"error": message})
	case codes.AlreadyExists:
		c.JSON(http.StatusConflict, gin.H{"error": message})
	case codes.FailedPrecondition:
		c.JSON(http.StatusPreconditionFailed, gin.H{"error": message})
	case codes.OutOfRange:
		c.JSON(http.StatusBadRequest, gin.H{"error": message})

	// Server errors
	case codes.Unavailable:
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Service temporarily unavailable"})
	case codes.DeadlineExceeded:
		c.JSON(http.StatusGatewayTimeout, gin.H{"error": "Request timed out"})
	case codes.ResourceExhausted:
		c.JSON(http.StatusTooManyRequests, gin.H{"error": "Rate limit exceeded"})
	case codes.Aborted:
		c.JSON(http.StatusConflict, gin.H{"error": message})

	// Internal server errors — log full details
	case codes.Internal, codes.DataLoss, codes.Unknown:
		log.Printf("[gRPC Internal Error] Code=%s Message=%s Err=%v\n", code, message, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Internal server error"})

	// Catch-all fallback
	default:
		log.Printf("[gRPC Unhandled Error] Code=%s Message=%s Err=%v\n", code, message, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Internal server error"})
	}

	return code
}
