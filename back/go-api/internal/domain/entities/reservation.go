package entities

import (
	"time"
)

// ReservationStatus represents the possible states of a reservation.
type ReservationStatus string

const (
	StatusPendente  ReservationStatus = "pendente"
	StatusConfirmada ReservationStatus = "confirmada"
	StatusCancelada  ReservationStatus = "cancelada"
)

// Reservation represents the core domain model for a Reservation.
type Reservation struct {
	ID           uint              `json:"id"`
	UserID       uint              `json:"user_id" validate:"required"`
	DataReserva  time.Time         `json:"data_reserva" validate:"required"`
	Status       ReservationStatus `json:"status" validate:"required"`
	CreatedAt    time.Time         `json:"created_at"`
	UpdatedAt    time.Time         `json:"updated_at"`
}
