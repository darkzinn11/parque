package usecases

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
	"github.com/darkzinn11/parque/back/go-api/internal/domain/repositories"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

var ErrInvalidCredentials = errors.New("credenciais inválidas")
var ErrInactiveAdminUser = errors.New("usuário administrativo inativo")

type AuthUseCase struct {
	repo      repositories.AdminUserRepository
	jwtSecret []byte
}

type LoginResult struct {
	Token string            `json:"token"`
	User  AdminUserSafeView `json:"usuario"`
}

type AdminUserSafeView struct {
	ID    uint   `json:"id"`
	Nome  string `json:"nome"`
	Email string `json:"email"`
	Cargo string `json:"cargo"`
}

type AdminClaims struct {
	UserID uint `json:"user_id"`
	jwt.RegisteredClaims
}

func NewAuthUseCase(repo repositories.AdminUserRepository, jwtSecret string) *AuthUseCase {
	return &AuthUseCase{
		repo:      repo,
		jwtSecret: []byte(jwtSecret),
	}
}

func (uc *AuthUseCase) SeedDefaultAdmin(ctx context.Context, name, email, password string) error {
	count, err := uc.repo.Count(ctx)
	if err != nil {
		return err
	}
	if count > 0 {
		return nil
	}

	email = strings.TrimSpace(strings.ToLower(email))
	if email == "" || strings.TrimSpace(password) == "" {
		return errors.New("credenciais iniciais do admin não configuradas")
	}

	passwordHash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return fmt.Errorf("erro ao gerar hash da senha inicial: %w", err)
	}

	return uc.repo.Create(ctx, &entities.AdminUser{
		Nome:         name,
		Email:        email,
		PasswordHash: string(passwordHash),
		Cargo:        "Administrador",
		Ativo:        true,
	})
}

func (uc *AuthUseCase) Login(ctx context.Context, email, password string) (*LoginResult, error) {
	email = strings.TrimSpace(strings.ToLower(email))
	user, err := uc.repo.GetByEmail(ctx, email)
	if err != nil {
		return nil, ErrInvalidCredentials
	}

	if !user.Ativo {
		return nil, ErrInactiveAdminUser
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
		return nil, ErrInvalidCredentials
	}

	token, err := uc.generateToken(user)
	if err != nil {
		return nil, err
	}

	if err := uc.repo.UpdateLastLogin(ctx, user.ID); err != nil {
		return nil, err
	}

	return &LoginResult{
		Token: token,
		User:  uc.toSafeView(user),
	}, nil
}

func (uc *AuthUseCase) Me(ctx context.Context, userID uint) (*AdminUserSafeView, error) {
	user, err := uc.repo.GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}

	view := uc.toSafeView(user)
	return &view, nil
}

func (uc *AuthUseCase) ParseToken(tokenString string) (*AdminClaims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &AdminClaims{}, func(token *jwt.Token) (any, error) {
		return uc.jwtSecret, nil
	})
	if err != nil {
		return nil, err
	}

	claims, ok := token.Claims.(*AdminClaims)
	if !ok || !token.Valid {
		return nil, errors.New("token inválido")
	}

	return claims, nil
}

func (uc *AuthUseCase) generateToken(user *entities.AdminUser) (string, error) {
	now := time.Now()
	claims := AdminClaims{
		UserID: user.ID,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   fmt.Sprintf("%d", user.ID),
			ExpiresAt: jwt.NewNumericDate(now.Add(12 * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(now),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(uc.jwtSecret)
}

func (uc *AuthUseCase) toSafeView(user *entities.AdminUser) AdminUserSafeView {
	return AdminUserSafeView{
		ID:    user.ID,
		Nome:  user.Nome,
		Email: user.Email,
		Cargo: user.Cargo,
	}
}
