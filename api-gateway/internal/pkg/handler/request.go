package handler

import (
	"fmt"

	"github.com/gin-gonic/gin"
)

func (h Handler) GetURLParam(c *gin.Context, param string) (string, bool) {
	value := c.Param(param)
	if value == "" {
		return "", false
	}
	return value, true
}

func (h Handler) GetQueryParam(c *gin.Context, param, defaultValue string) string {
	return c.DefaultQuery(param, defaultValue)
}

func (h Handler) GetRequiredQueryParam(c *gin.Context, param string) (string, error) {
	value := c.Query(param)
	if value == "" {
		return "", fmt.Errorf("missing required query parameter: %s", param)
	}
	return value, nil
}
