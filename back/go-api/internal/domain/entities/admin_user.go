package entities

import "time"

// AdminUser represents an authenticated admin panel user.
type AdminUser struct {
	ID           uint       `json:"id" gorm:"primaryKey"`
	Nome         string     `json:"nome" gorm:"size:120;not null"`
	Email        string     `json:"email" gorm:"size:191;uniqueIndex;not null"`
	PasswordHash string     `json:"-" gorm:"column:password_hash;size:255;not null"`
	Cargo        string     `json:"cargo" gorm:"size:120"`
	Ativo        bool       `json:"ativo" gorm:"default:true"`
	LastLoginAt  *time.Time `json:"last_login_at"`
	CreatedAt    time.Time  `json:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at"`
}
