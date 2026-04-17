package usecases

import (
	"context"

	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
	"github.com/darkzinn11/parque/back/go-api/internal/domain/repositories"
)

type ReviewUseCase struct {
	repo repositories.ReviewRepository
}

func NewReviewUseCase(repo repositories.ReviewRepository) *ReviewUseCase {
	return &ReviewUseCase{repo: repo}
}

func (uc *ReviewUseCase) List(ctx context.Context) ([]entities.Review, error) {
	return uc.repo.List(ctx)
}

func (uc *ReviewUseCase) GetByID(ctx context.Context, id uint) (*entities.Review, error) {
	return uc.repo.GetByID(ctx, id)
}

func (uc *ReviewUseCase) Create(ctx context.Context, review *entities.Review) error {
	return uc.repo.Create(ctx, review)
}

func (uc *ReviewUseCase) Update(ctx context.Context, review *entities.Review) error {
	return uc.repo.Update(ctx, review)
}

func (uc *ReviewUseCase) Delete(ctx context.Context, id uint) error {
	return uc.repo.Delete(ctx, id)
}
