package http

import (
	"github.com/gin-gonic/gin"
)

func NewRouter(jobHandler *JobHandler) *gin.Engine {
	r := gin.Default()

	// Group API routes
	api := r.Group("/api/v1")
	{
		api.POST("/jobs", jobHandler.CreateJob)
	}

	return r
}
