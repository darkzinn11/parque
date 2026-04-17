package usecases

import (
	"context"

	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
	"github.com/darkzinn11/parque/back/go-api/internal/domain/repositories"
)

type MapPointUseCase struct {
	repo repositories.MapPointRepository
}

func NewMapPointUseCase(repo repositories.MapPointRepository) *MapPointUseCase {
	return &MapPointUseCase{repo: repo}
}

func (uc *MapPointUseCase) List(ctx context.Context) ([]entities.MapPoint, error) {
	return uc.repo.List(ctx)
}

func (uc *MapPointUseCase) GetByID(ctx context.Context, id uint) (*entities.MapPoint, error) {
	return uc.repo.GetByID(ctx, id)
}

func (uc *MapPointUseCase) Create(ctx context.Context, mapPoint *entities.MapPoint) error {
	return uc.repo.Create(ctx, mapPoint)
}

func (uc *MapPointUseCase) Update(ctx context.Context, mapPoint *entities.MapPoint) error {
	return uc.repo.Update(ctx, mapPoint)
}

func (uc *MapPointUseCase) Delete(ctx context.Context, id uint) error {
	return uc.repo.Delete(ctx, id)
}
