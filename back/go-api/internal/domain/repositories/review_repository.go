package repositories

import (
	"context"

	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
)

type ReviewRepository interface {
	GetByID(ctx context.Context, id uint) (*entities.Review, error)
	List(ctx context.Context) ([]entities.Review, error)
	Create(ctx context.Context, review *entities.Review) error
	Update(ctx context.Context, review *entities.Review) error
	Delete(ctx context.Context, id uint) error
}
