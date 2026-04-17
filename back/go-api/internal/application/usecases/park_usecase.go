package usecases

import (
	"context"

	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
	"github.com/darkzinn11/parque/back/go-api/internal/domain/repositories"
)

type ParkUseCase struct {
	repo repositories.ParkRepository
}

func NewParkUseCase(repo repositories.ParkRepository) *ParkUseCase {
	return &ParkUseCase{repo: repo}
}

func (uc *ParkUseCase) ListParks(ctx context.Context) ([]entities.Park, error) {
	return uc.repo.List(ctx)
}

func (uc *ParkUseCase) GetPark(ctx context.Context, id uint) (*entities.Park, error) {
	return uc.repo.GetByID(ctx, id)
}

func (uc *ParkUseCase) CreatePark(ctx context.Context, park *entities.Park) error {
	// Here we could add business rules (e.g. check if name exists, map formats)
	return uc.repo.Create(ctx, park)
}

func (uc *ParkUseCase) UpdatePark(ctx context.Context, park *entities.Park) error {
	return uc.repo.Update(ctx, park)
}

func (uc *ParkUseCase) DeletePark(ctx context.Context, id uint) error {
	return uc.repo.Delete(ctx, id)
}
