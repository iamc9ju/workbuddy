package service

import (
	"context"
	"fmt"

	"github.com/iamc9ju/workbuddy/internal/core/domain"
	"github.com/iamc9ju/workbuddy/internal/core/port"
	"github.com/pgvector/pgvector-go"
)

type JobService struct {
	repo      port.JobRepository
	aiService port.AIService
}

func NewJobService(repo port.JobRepository, ai port.AIService) *JobService {
	return &JobService{
		repo:      repo,
		aiService: ai,
	}
}

func (s *JobService) CreateJob(ctx context.Context, title, desc, req string) error {
	// 1. รวม Text เพื่อทำ Embedding (Title + Desc + Req)
	fullText := fmt.Sprintf("%s. %s. %s", title, desc, req)

	// 2. เรียก AI Adapter สร้าง Vector
	vector, err := s.aiService.GenerateEmbedding(ctx, fullText)
	if err != nil {
		return err
	}

	// 3. สร้าง Domain Object
	job := domain.Job{
		Title:        title,
		Description:  desc,
		Requirements: req,
		Embedding:    pgvector.NewVector(vector), // แปลง []float32 เป็น pgvector type
	}

	// 4. บันทึกลง DB
	return s.repo.Create(ctx, &job)
}
