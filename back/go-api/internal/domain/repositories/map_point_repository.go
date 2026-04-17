package repositories

import (
	"context"

	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
)

type MapPointRepository interface {
	GetByID(ctx context.Context, id uint) (*entities.MapPoint, error)
	List(ctx context.Context) ([]entities.MapPoint, error)
	Create(ctx context.Context, mapPoint *entities.MapPoint) error
	Update(ctx context.Context, mapPoint *entities.MapPoint) error
	Delete(ctx context.Context, id uint) error
}
