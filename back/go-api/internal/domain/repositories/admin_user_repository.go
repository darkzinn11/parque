package repositories

import (
	"context"

	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
)

type AdminUserRepository interface {
	Count(ctx context.Context) (int64, error)
	GetByEmail(ctx context.Context, email string) (*entities.AdminUser, error)
	GetByID(ctx context.Context, id uint) (*entities.AdminUser, error)
	Create(ctx context.Context, user *entities.AdminUser) error
	UpdateLastLogin(ctx context.Context, id uint) error
}
