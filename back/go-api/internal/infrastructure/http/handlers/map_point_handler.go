package handlers

import (
	"net/http"
	"strconv"

	"github.com/darkzinn11/parque/back/go-api/internal/application/usecases"
	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
	"github.com/gin-gonic/gin"
)

type MapPointHandler struct {
	useCase *usecases.MapPointUseCase
}

func NewMapPointHandler(useCase *usecases.MapPointUseCase) *MapPointHandler {
	return &MapPointHandler{useCase: useCase}
}

func (h *MapPointHandler) List(c *gin.Context) {
	mapPoints, err := h.useCase.List(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, mapPoints)
}

func (h *MapPointHandler) GetByID(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid map point id"})
		return
	}

	mapPoint, err := h.useCase.GetByID(c.Request.Context(), uint(id))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "map point not found"})
		return
	}
	c.JSON(http.StatusOK, mapPoint)
}

func (h *MapPointHandler) Create(c *gin.Context) {
	var input entities.MapPoint
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := h.useCase.Create(c.Request.Context(), &input); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, input)
}

func (h *MapPointHandler) Update(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid map point id"})
		return
	}

	mapPoint, err := h.useCase.GetByID(c.Request.Context(), uint(id))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "map point not found"})
		return
	}

	if err := c.ShouldBindJSON(mapPoint); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	mapPoint.ID = uint(id)

	if err := h.useCase.Update(c.Request.Context(), mapPoint); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, mapPoint)
}

func (h *MapPointHandler) Delete(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid map point id"})
		return
	}

	if err := h.useCase.Delete(c.Request.Context(), uint(id)); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusNoContent, nil)
}
