package persistence

import (
	"context"
	"time"

	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
	"github.com/darkzinn11/parque/back/go-api/internal/domain/repositories"
	"gorm.io/gorm"
)

type mysqlDashboardRepository struct {
	db *gorm.DB
}

func NewMySQLDashboardRepository(db *gorm.DB) repositories.DashboardRepository {
	return &mysqlDashboardRepository{db: db}
}

func (r *mysqlDashboardRepository) GetStats(ctx context.Context) (*entities.DashboardStats, error) {
	stats := &entities.DashboardStats{}

	if err := r.db.WithContext(ctx).Model(&entities.Park{}).Count(&stats.TotalParques).Error; err != nil {
		return nil, err
	}
	if err := r.db.WithContext(ctx).Model(&entities.Reservation{}).Count(&stats.TotalReservas).Error; err != nil {
		return nil, err
	}
	if err := r.db.WithContext(ctx).Model(&entities.Reservation{}).Where("status = ?", entities.StatusPendente).Count(&stats.ReservasPendentes).Error; err != nil {
		return nil, err
	}
	if err := r.db.WithContext(ctx).Model(&entities.Review{}).Count(&stats.TotalAvaliacoes).Error; err != nil {
		return nil, err
	}
	if err := r.db.WithContext(ctx).Model(&entities.Activity{}).Count(&stats.TotalAtividades).Error; err != nil {
		return nil, err
	}

	var upcoming []entities.Reservation
	if err := r.db.WithContext(ctx).
		Where("data_reserva >= ?", time.Now()).
		Order("data_reserva asc").
		Limit(5).
		Find(&upcoming).Error; err != nil {
		return nil, err
	}

	stats.ProximasReservas = make([]entities.DashboardReservationItem, 0, len(upcoming))
	for _, reservation := range upcoming {
		stats.ProximasReservas = append(stats.ProximasReservas, entities.DashboardReservationItem{
			ID:          reservation.ID,
			UserID:      reservation.UserID,
			DataReserva: reservation.DataReserva,
			Status:      string(reservation.Status),
		})
	}

	return stats, nil
}
