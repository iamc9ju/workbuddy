package postgres

import (
	"context"

	"github.com/iamc9ju/workbuddy/internal/core/domain"
	"github.com/pgvector/pgvector-go"
	"gorm.io/gorm"
)

type JobRepositoryPostgres struct {
	db *gorm.DB
}

func NewJobRepository(db *gorm.DB) *JobRepositoryPostgres {
	return &JobRepositoryPostgres{db: db}
}

func (r *JobRepositoryPostgres) Create(ctx context.Context, job *domain.Job) error {
	return r.db.WithContext(ctx).Create(job).Error
}

func (r *JobRepositoryPostgres) SearchByVector(ctx context.Context, vector []float32, limit int) ([]domain.Job, error) {
	var jobs []domain.Job

	// ใช้ pgvector operator (<-> คือ L2 distance, <=> คือ Cosine distance)
	// สำหรับ Matching ความเหมือน เรามักใช้ Cosine Distance (<=>) และ order by distance
	err := r.db.WithContext(ctx).
		Order(gorm.Expr("embedding <=> ?", pgvector.NewVector(vector))).
		Limit(limit).
		Find(&jobs).Error

	return jobs, err
}
