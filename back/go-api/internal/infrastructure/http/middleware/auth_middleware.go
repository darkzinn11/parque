package middleware

import (
	"net/http"
	"strings"

	"github.com/darkzinn11/parque/back/go-api/internal/application/usecases"
	"github.com/gin-gonic/gin"
)

func RequireAdminAuth(authUseCase *usecases.AuthUseCase) gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "token ausente"})
			return
		}

		token := strings.TrimSpace(strings.TrimPrefix(header, "Bearer "))
		claims, err := authUseCase.ParseToken(token)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "token inválido"})
			return
		}

		c.Set("admin_user_id", claims.UserID)
		c.Next()
	}
}
