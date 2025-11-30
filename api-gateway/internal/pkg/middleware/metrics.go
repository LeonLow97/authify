package middleware

import (
	"fmt"
	"time"

	"github.com/LeonLow97/internal/metrics"
	"github.com/gin-gonic/gin"
)

func (m *middleware) MetricsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		path := c.FullPath()
		method := c.Request.Method

		metrics.InFlightRequests.Inc()
		start := time.Now()

		// Proceed to next handler first before recording response status in metrics
		c.Next()

		metrics.InFlightRequests.Dec()
		status := fmt.Sprintf("%d", c.Writer.Status())
		duration := time.Since(start).Seconds()

		metrics.HTTPRequests.WithLabelValues(method, path, status).Inc()
		metrics.HTTPReqLatency.WithLabelValues(method, path).Observe(duration)
	}
}
