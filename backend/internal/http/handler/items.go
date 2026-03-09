package handler

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/klausmeyer/pantry/backend/internal/domain/item"
	"github.com/klausmeyer/pantry/backend/internal/service"
	"github.com/klausmeyer/pantry/backend/pkg/httputil"
)

type ItemsHandler struct {
	service *service.ItemService
}

func NewItemsHandler(svc *service.ItemService) *ItemsHandler {
	return &ItemsHandler{service: svc}
}

func (h *ItemsHandler) List(w http.ResponseWriter, r *http.Request) {
	items, err := h.service.List(r.Context())
	if err != nil {
		httputil.WriteJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{"data": items})
}

func (h *ItemsHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Name          string    `json:"name"`
		BestBefore    string    `json:"best_before"`
		ContentAmount float64   `json:"content_amount"`
		ContentUnit   item.Unit `json:"content_unit"`
		PictureKey    string    `json:"picture_key"`
		Comment       *string   `json:"comment"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		return
	}

	bestBefore, err := time.Parse(time.DateOnly, req.BestBefore)
	if err != nil {
		httputil.WriteJSON(w, http.StatusBadRequest, map[string]string{"error": "best_before must use YYYY-MM-DD"})
		return
	}

	created, err := h.service.Create(r.Context(), service.CreateItemInput{
		Name:          req.Name,
		BestBefore:    bestBefore,
		ContentAmount: req.ContentAmount,
		ContentUnit:   req.ContentUnit,
		PictureKey:    req.PictureKey,
		Comment:       req.Comment,
	})
	if err != nil {
		httputil.WriteJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}

	httputil.WriteJSON(w, http.StatusCreated, map[string]any{"data": created})
}
