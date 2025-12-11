package port

import (
	"context"

	"github.com/iamc9ju/workbuddy/internal/core/domain"
)

type JobRepository interface {
	Create(ctx context.Context, job *domain.Job) error
	// Search ค้นหาด้วย Vector
	SearchByVector(ctx context.Context, vector []float32, limit int) ([]domain.Job, error)
}
