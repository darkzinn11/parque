package repositories

import (
	"context"
	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
)

// ParkRepository defines the interface for park data operations.
type ParkRepository interface {
	GetByID(ctx context.Context, id uint) (*entities.Park, error)
	List(ctx context.Context) ([]entities.Park, error)
	Create(ctx context.Context, park *entities.Park) error
	Update(ctx context.Context, park *entities.Park) error
	Delete(ctx context.Context, id uint) error
}
