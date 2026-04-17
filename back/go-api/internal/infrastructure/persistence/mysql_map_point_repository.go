package persistence

import (
	"context"

	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
	"github.com/darkzinn11/parque/back/go-api/internal/domain/repositories"
	"gorm.io/gorm"
)

type mysqlMapPointRepository struct {
	db *gorm.DB
}

func NewMySQLMapPointRepository(db *gorm.DB) repositories.MapPointRepository {
	return &mysqlMapPointRepository{db: db}
}

func (r *mysqlMapPointRepository) GetByID(ctx context.Context, id uint) (*entities.MapPoint, error) {
	var mapPoint entities.MapPoint
	if err := r.db.WithContext(ctx).Preload("Park").First(&mapPoint, id).Error; err != nil {
		return nil, err
	}
	return &mapPoint, nil
}

func (r *mysqlMapPointRepository) List(ctx context.Context) ([]entities.MapPoint, error) {
	var mapPoints []entities.MapPoint
	if err := r.db.WithContext(ctx).Preload("Park").Order("id desc").Find(&mapPoints).Error; err != nil {
		return nil, err
	}
	return mapPoints, nil
}

func (r *mysqlMapPointRepository) Create(ctx context.Context, mapPoint *entities.MapPoint) error {
	return r.db.WithContext(ctx).Create(mapPoint).Error
}

func (r *mysqlMapPointRepository) Update(ctx context.Context, mapPoint *entities.MapPoint) error {
	return r.db.WithContext(ctx).Save(mapPoint).Error
}

func (r *mysqlMapPointRepository) Delete(ctx context.Context, id uint) error {
	return r.db.WithContext(ctx).Delete(&entities.MapPoint{}, id).Error
}
