package entities

import (
	"time"
)

// Park represents the core domain model for a Park.
type Park struct {
	ID          uint      `json:"id"`
	Nome        string    `json:"nome" validate:"required"`
	Descricao   string    `json:"descricao"`
	ImagemURL   string    `json:"imagem_url"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
	DeletedAt   *time.Time `json:"deleted_at,omitempty"`
}
