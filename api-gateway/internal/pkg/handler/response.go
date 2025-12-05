package handler

import "github.com/gin-gonic/gin"

func (h Handler) ResponseJSON(c *gin.Context, statusCode int, data any) {
	c.JSON(statusCode, gin.H{"data": data})
}

func (h Handler) ResponseNoContent(c *gin.Context, statusCode int) {
	c.Status(statusCode)
}
