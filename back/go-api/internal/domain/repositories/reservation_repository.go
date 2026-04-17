package repositories

import (
	"context"
	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
)

// ReservationRepository defines the interface for reservation data operations.
type ReservationRepository interface {
	GetByUserID(ctx context.Context, userID uint) ([]entities.Reservation, error)
	GetByID(ctx context.Context, id uint) (*entities.Reservation, error)
	Create(ctx context.Context, reservation *entities.Reservation) error
	UpdateStatus(ctx context.Context, id uint, status entities.ReservationStatus) error
}
