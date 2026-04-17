package persistence

import (
	"context"

	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
	"github.com/darkzinn11/parque/back/go-api/internal/domain/repositories"
	"gorm.io/gorm"
)

type mysqlReviewRepository struct {
	db *gorm.DB
}

func NewMySQLReviewRepository(db *gorm.DB) repositories.ReviewRepository {
	return &mysqlReviewRepository{db: db}
}

func (r *mysqlReviewRepository) GetByID(ctx context.Context, id uint) (*entities.Review, error) {
	var review entities.Review
	if err := r.db.WithContext(ctx).Preload("Park").First(&review, id).Error; err != nil {
		return nil, err
	}
	return &review, nil
}

func (r *mysqlReviewRepository) List(ctx context.Context) ([]entities.Review, error) {
	var reviews []entities.Review
	if err := r.db.WithContext(ctx).Preload("Park").Order("id desc").Find(&reviews).Error; err != nil {
		return nil, err
	}
	return reviews, nil
}

func (r *mysqlReviewRepository) Create(ctx context.Context, review *entities.Review) error {
	return r.db.WithContext(ctx).Create(review).Error
}

func (r *mysqlReviewRepository) Update(ctx context.Context, review *entities.Review) error {
	return r.db.WithContext(ctx).Save(review).Error
}

func (r *mysqlReviewRepository) Delete(ctx context.Context, id uint) error {
	return r.db.WithContext(ctx).Delete(&entities.Review{}, id).Error
}
