package handlers

import (
	"net/http"
	"strconv"

	"github.com/darkzinn11/parque/back/go-api/internal/application/usecases"
	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
	"github.com/gin-gonic/gin"
)

type ParkHandler struct {
	useCase *usecases.ParkUseCase
}

func NewParkHandler(useCase *usecases.ParkUseCase) *ParkHandler {
	return &ParkHandler{useCase: useCase}
}

func (h *ParkHandler) ListParks(c *gin.Context) {
	parks, err := h.useCase.ListParks(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, parks)
}

func (h *ParkHandler) GetPark(c *gin.Context) {
	idParam := c.Param("id")
	id, err := strconv.ParseUint(idParam, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid park id"})
		return
	}

	park, err := h.useCase.GetPark(c.Request.Context(), uint(id))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "park not found"})
		return
	}
	c.JSON(http.StatusOK, park)
}

func (h *ParkHandler) CreatePark(c *gin.Context) {
	var input entities.Park
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := h.useCase.CreatePark(c.Request.Context(), &input); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, input)
}

func (h *ParkHandler) UpdatePark(c *gin.Context) {
	idParam := c.Param("id")
	id, err := strconv.ParseUint(idParam, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid park id"})
		return
	}

	park, err := h.useCase.GetPark(c.Request.Context(), uint(id))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "park not found"})
		return
	}

	if err := c.ShouldBindJSON(park); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Keep the same ID
	park.ID = uint(id)

	if err := h.useCase.UpdatePark(c.Request.Context(), park); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, park)
}

func (h *ParkHandler) DeletePark(c *gin.Context) {
	idParam := c.Param("id")
	id, err := strconv.ParseUint(idParam, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid park id"})
		return
	}

	if err := h.useCase.DeletePark(c.Request.Context(), uint(id)); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusNoContent, nil)
}
