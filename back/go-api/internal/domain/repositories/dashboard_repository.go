package repositories

import (
	"context"

	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
)

type DashboardRepository interface {
	GetStats(ctx context.Context) (*entities.DashboardStats, error)
}
