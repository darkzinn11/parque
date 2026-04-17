package persistence

import (
	"context"
	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
	"github.com/darkzinn11/parque/back/go-api/internal/domain/repositories"
	"gorm.io/gorm"
)

type mysqlReservationRepository struct {
	db *gorm.DB
}

// NewMySQLReservationRepository creates a new instance of the MySQL reservation repository.
func NewMySQLReservationRepository(db *gorm.DB) repositories.ReservationRepository {
	return &mysqlReservationRepository{db: db}
}

func (r *mysqlReservationRepository) GetByUserID(ctx context.Context, userID uint) ([]entities.Reservation, error) {
	var reservations []entities.Reservation
	if err := r.db.WithContext(ctx).Where("user_id = ?", userID).Find(&reservations).Error; err != nil {
		return nil, err
	}
	return reservations, nil
}

func (r *mysqlReservationRepository) GetByID(ctx context.Context, id uint) (*entities.Reservation, error) {
	var res entities.Reservation
	if err := r.db.WithContext(ctx).First(&res, id).Error; err != nil {
		return nil, err
	}
	return &res, nil
}

func (r *mysqlReservationRepository) Create(ctx context.Context, res *entities.Reservation) error {
	return r.db.WithContext(ctx).Create(res).Error
}

func (r *mysqlReservationRepository) UpdateStatus(ctx context.Context, id uint, status entities.ReservationStatus) error {
	return r.db.WithContext(ctx).Model(&entities.Reservation{}).Where("id = ?", id).Update("status", status).Error
}
