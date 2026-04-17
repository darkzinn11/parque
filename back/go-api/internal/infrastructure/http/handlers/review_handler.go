package handlers

import (
	"net/http"
	"strconv"

	"github.com/darkzinn11/parque/back/go-api/internal/application/usecases"
	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
	"github.com/gin-gonic/gin"
)

type ReviewHandler struct {
	useCase *usecases.ReviewUseCase
}

func NewReviewHandler(useCase *usecases.ReviewUseCase) *ReviewHandler {
	return &ReviewHandler{useCase: useCase}
}

func (h *ReviewHandler) List(c *gin.Context) {
	reviews, err := h.useCase.List(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, reviews)
}

func (h *ReviewHandler) GetByID(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid review id"})
		return
	}

	review, err := h.useCase.GetByID(c.Request.Context(), uint(id))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "review not found"})
		return
	}
	c.JSON(http.StatusOK, review)
}

func (h *ReviewHandler) Create(c *gin.Context) {
	var input entities.Review
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

func (h *ReviewHandler) Update(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid review id"})
		return
	}

	review, err := h.useCase.GetByID(c.Request.Context(), uint(id))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "review not found"})
		return
	}

	if err := c.ShouldBindJSON(review); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	review.ID = uint(id)

	if err := h.useCase.Update(c.Request.Context(), review); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, review)
}

func (h *ReviewHandler) Delete(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid review id"})
		return
	}

	if err := h.useCase.Delete(c.Request.Context(), uint(id)); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusNoContent, nil)
}
