// internal/core/domain/job.go
package domain

import (
	"time"

	"github.com/google/uuid"
	"github.com/pgvector/pgvector-go" // แนะนำให้ใช้ lib นี้คู่กับ gorm
)

type Job struct {
	JobID               uuid.UUID        `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	Title            string           `gorm:"not null"`
	Description      string           `gorm:"not null"` // Raw text description
	Requirements     string           `gorm:"not null"`
	Embedding        pgvector.Vector  `gorm:"type:vector(1536)"` // สำคัญ: ขนาดต้องตรงกับ Model AI ที่ใช้
	CreatedAt        time.Time
	UpdatedAt        time.Time
}

// Helper method สำหรับ Domain Logic (ถ้ามี)
func NewJob(title, desc, req string) *Job {
	return &Job{
		Title:        title,
		Description:  desc,
		Requirements: req,
	}
}
