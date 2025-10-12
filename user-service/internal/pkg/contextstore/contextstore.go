package contextstore

import (
	"context"
	"fmt"
	"log"
	"strconv"

	"google.golang.org/grpc/metadata"
)

func UserIDFromContext(ctx context.Context) (int64, error) {
	// Retrieve UserID from grpc incoming context
	md, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		log.Println("No metadata found in context")
		return 0, fmt.Errorf("grpc metadata not found in context")
	}
	userIDStr := md["user_id"]
	userID, err := strconv.Atoi(userIDStr[0])
	if err != nil {
		return 0, fmt.Errorf("failed to convert user ID in grpc metadata to int")
	}
	return int64(userID), nil
}
