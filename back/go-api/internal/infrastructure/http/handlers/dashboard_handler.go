package handlers

import (
	"net/http"

	"github.com/darkzinn11/parque/back/go-api/internal/application/usecases"
	"github.com/gin-gonic/gin"
)

type DashboardHandler struct {
	useCase *usecases.DashboardUseCase
}

func NewDashboardHandler(useCase *usecases.DashboardUseCase) *DashboardHandler {
	return &DashboardHandler{useCase: useCase}
}

func (h *DashboardHandler) GetStats(c *gin.Context) {
	stats, err := h.useCase.GetStats(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, stats)
}
