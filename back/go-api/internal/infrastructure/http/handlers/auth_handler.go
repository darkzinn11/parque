package handlers

import (
	"errors"
	"net/http"

	"github.com/darkzinn11/parque/back/go-api/internal/application/usecases"
	"github.com/gin-gonic/gin"
)

type AuthHandler struct {
	useCase *usecases.AuthUseCase
}

type loginRequest struct {
	Email string `json:"email" binding:"required,email"`
	Senha string `json:"senha" binding:"required,min=6"`
}

func NewAuthHandler(useCase *usecases.AuthUseCase) *AuthHandler {
	return &AuthHandler{useCase: useCase}
}

func (h *AuthHandler) Login(c *gin.Context) {
	var input loginRequest
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "dados de login inválidos"})
		return
	}

	result, err := h.useCase.Login(c.Request.Context(), input.Email, input.Senha)
	if err != nil {
		switch {
		case errors.Is(err, usecases.ErrInvalidCredentials):
			c.JSON(http.StatusUnauthorized, gin.H{"error": "e-mail ou senha inválidos"})
		case errors.Is(err, usecases.ErrInactiveAdminUser):
			c.JSON(http.StatusForbidden, gin.H{"error": "usuário administrativo inativo"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		}
		return
	}

	c.JSON(http.StatusOK, result)
}

func (h *AuthHandler) Me(c *gin.Context) {
	userIDValue, exists := c.Get("admin_user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "usuário não autenticado"})
		return
	}

	userID, ok := userIDValue.(uint)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "sessão inválida"})
		return
	}

	user, err := h.useCase.Me(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "usuário não encontrado"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"usuario": user})
}
