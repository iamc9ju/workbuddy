package ai

import (
	"context"

	"github.com/iamc9ju/workbuddy/internal/core/port"
	"github.com/sashabaranov/go-openai" // Library มาตรฐาน
)

type OpenAIAdapter struct {
	client *openai.Client
}

func NewOpenAIAdapter(apiKey string) port.AIService {
	return &OpenAIAdapter{
		client: openai.NewClient(apiKey),
	}
}

func (a *OpenAIAdapter) GenerateEmbedding(ctx context.Context, text string) ([]float32, error) {
	resp, err := a.client.CreateEmbeddings(ctx, openai.EmbeddingRequest{
		Input: []string{text},
		Model: openai.SmallEmbedding3, // ราคาถูกและดีสำหรับ MVP
	})
	if err != nil {
		return nil, err
	}
	return resp.Data[0].Embedding, nil
}
