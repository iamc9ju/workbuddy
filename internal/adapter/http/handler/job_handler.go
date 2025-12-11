package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	service "github.com/iamc9ju/workbuddy/internal/core/services"
)

type JobHandler struct {
	svc *service.JobService
}

func NewJobHandler(svc *service.JobService) *JobHandler {
	return &JobHandler{svc: svc}
}

type CreateJobRequest struct {
	Title        string `json:"title" binding:"required"`
	Description  string `json:"description" binding:"required"`
	Requirements string `json:"requirements" binding:"required"`
}

func (h *JobHandler) CreateJob(c *gin.Context) {
	var req CreateJobRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// เรียก Service
	if err := h.svc.CreateJob(c.Request.Context(), req.Title, req.Description, req.Requirements); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"message": "Job created successfully"})
}
