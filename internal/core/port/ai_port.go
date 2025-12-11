package port

import "context"

type AIService interface {
	// GenerateEmbedding แปลง text เป็น vector
	GenerateEmbedding(ctx context.Context, text string) ([]float32, error)
}
