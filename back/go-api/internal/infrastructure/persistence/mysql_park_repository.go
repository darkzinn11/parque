package persistence

import (
	"context"
	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
	"github.com/darkzinn11/parque/back/go-api/internal/domain/repositories"
	"gorm.io/gorm"
)

type mysqlParkRepository struct {
	db *gorm.DB
}

// NewMySQLParkRepository creates a new instance of the MySQL park repository.
func NewMySQLParkRepository(db *gorm.DB) repositories.ParkRepository {
	return &mysqlParkRepository{db: db}
}

func (r *mysqlParkRepository) GetByID(ctx context.Context, id uint) (*entities.Park, error) {
	var park entities.Park
	if err := r.db.WithContext(ctx).First(&park, id).Error; err != nil {
		return nil, err
	}
	return &park, nil
}

func (r *mysqlParkRepository) List(ctx context.Context) ([]entities.Park, error) {
	var parks []entities.Park
	if err := r.db.WithContext(ctx).Find(&parks).Error; err != nil {
		return nil, err
	}
	return parks, nil
}

func (r *mysqlParkRepository) Create(ctx context.Context, park *entities.Park) error {
	return r.db.WithContext(ctx).Create(park).Error
}

func (r *mysqlParkRepository) Update(ctx context.Context, park *entities.Park) error {
	return r.db.WithContext(ctx).Save(park).Error
}

func (r *mysqlParkRepository) Delete(ctx context.Context, id uint) error {
	return r.db.WithContext(ctx).Delete(&entities.Park{}, id).Error
}
