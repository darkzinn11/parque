package entities

import "time"

type DashboardReservationItem struct {
	ID          uint      `json:"id"`
	UserID      uint      `json:"user_id"`
	DataReserva time.Time `json:"data_reserva"`
	Status      string    `json:"status"`
}

type DashboardStats struct {
	TotalParques      int64                      `json:"total_parques"`
	TotalReservas     int64                      `json:"total_reservas"`
	ReservasPendentes int64                      `json:"reservas_pendentes"`
	TotalAvaliacoes   int64                      `json:"total_avaliacoes"`
	TotalAtividades   int64                      `json:"total_atividades"`
	ProximasReservas  []DashboardReservationItem `json:"proximas_reservas"`
}
