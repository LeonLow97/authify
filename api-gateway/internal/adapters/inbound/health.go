package inbound

import (
	"context"
	"net/http"
	"time"

	"github.com/LeonLow97/internal/cache"
	"github.com/gin-gonic/gin"
)

type HealthHandler struct {
	cacheClient cache.Cache
}

func NewHealthHandler(cacheClient cache.Cache) *HealthHandler {
	return &HealthHandler{
		cacheClient: cacheClient,
	}
}

// Liveness just checks if the app process is running.
func (h *HealthHandler) Liveness(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":  "alive",
		"message": "api gateway is running",
	})
}

// Readiness checks external dependencies
func (h *HealthHandler) Readiness(c *gin.Context) {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	if err := h.cacheClient.Ping(ctx); err != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{
			"status": "unhealthy",
			"error":  "redis down: " + err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status":  "ready",
		"message": "all systems operational",
	})
}
