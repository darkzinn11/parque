package persistence

import (
	"context"
	"strings"
	"time"

	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
	"github.com/darkzinn11/parque/back/go-api/internal/domain/repositories"
	"gorm.io/gorm"
)

type mysqlAdminUserRepository struct {
	db *gorm.DB
}

func NewMySQLAdminUserRepository(db *gorm.DB) repositories.AdminUserRepository {
	return &mysqlAdminUserRepository{db: db}
}

func (r *mysqlAdminUserRepository) Count(ctx context.Context) (int64, error) {
	var count int64
	err := r.db.WithContext(ctx).Model(&entities.AdminUser{}).Count(&count).Error
	return count, err
}

func (r *mysqlAdminUserRepository) GetByEmail(ctx context.Context, email string) (*entities.AdminUser, error) {
	var user entities.AdminUser
	if err := r.db.WithContext(ctx).
		Where("LOWER(email) = ?", strings.ToLower(email)).
		First(&user).Error; err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *mysqlAdminUserRepository) GetByID(ctx context.Context, id uint) (*entities.AdminUser, error) {
	var user entities.AdminUser
	if err := r.db.WithContext(ctx).First(&user, id).Error; err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *mysqlAdminUserRepository) Create(ctx context.Context, user *entities.AdminUser) error {
	return r.db.WithContext(ctx).Create(user).Error
}

func (r *mysqlAdminUserRepository) UpdateLastLogin(ctx context.Context, id uint) error {
	now := time.Now()
	return r.db.WithContext(ctx).
		Model(&entities.AdminUser{}).
		Where("id = ?", id).
		Update("last_login_at", &now).
		Error
}
