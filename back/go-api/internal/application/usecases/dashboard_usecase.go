package usecases

import (
	"context"

	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
	"github.com/darkzinn11/parque/back/go-api/internal/domain/repositories"
)

type DashboardUseCase struct {
	repo repositories.DashboardRepository
}

func NewDashboardUseCase(repo repositories.DashboardRepository) *DashboardUseCase {
	return &DashboardUseCase{repo: repo}
}

func (uc *DashboardUseCase) GetStats(ctx context.Context) (*entities.DashboardStats, error) {
	return uc.repo.GetStats(ctx)
}
