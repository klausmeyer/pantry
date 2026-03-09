package handler

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/klausmeyer/pantry/backend/internal/domain/item"
	"github.com/klausmeyer/pantry/backend/internal/service"
	"github.com/klausmeyer/pantry/backend/pkg/httputil"
)

const itemType = "items"

type ItemsHandler struct {
	service *service.ItemService
}

func NewItemsHandler(svc *service.ItemService) *ItemsHandler {
	return &ItemsHandler{service: svc}
}

type itemAttributes struct {
	Name          string  `json:"name"`
	BestBefore    string  `json:"best_before"`
	ContentAmount float64 `json:"content_amount"`
	ContentUnit   string  `json:"content_unit"`
	PictureKey    string  `json:"picture_key"`
	Comment       *string `json:"comment,omitempty"`
	CreatedAt     string  `json:"created_at"`
	UpdatedAt     string  `json:"updated_at"`
}

type itemResource struct {
	Type       string         `json:"type"`
	ID         string         `json:"id"`
	Attributes itemAttributes `json:"attributes"`
}

type createItemAttributes struct {
	Name          string    `json:"name"`
	BestBefore    string    `json:"best_before"`
	ContentAmount float64   `json:"content_amount"`
	ContentUnit   item.Unit `json:"content_unit"`
	PictureKey    string    `json:"picture_key"`
	Comment       *string   `json:"comment"`
}

type createItemDocument struct {
	Data struct {
		Type       string               `json:"type"`
		Attributes createItemAttributes `json:"attributes"`
	} `json:"data"`
}

func toItemResource(i item.Item) itemResource {
	return itemResource{
		Type: itemType,
		ID:   i.ID,
		Attributes: itemAttributes{
			Name:          i.Name,
			BestBefore:    i.BestBefore.UTC().Format(time.DateOnly),
			ContentAmount: i.ContentAmount,
			ContentUnit:   string(i.ContentUnit),
			PictureKey:    i.PictureKey,
			Comment:       i.Comment,
			CreatedAt:     i.CreatedAt.UTC().Format(time.RFC3339),
			UpdatedAt:     i.UpdatedAt.UTC().Format(time.RFC3339),
		},
	}
}

func (h *ItemsHandler) List(w http.ResponseWriter, r *http.Request) {
	items, err := h.service.List(r.Context())
	if err != nil {
		httputil.WriteJSONAPIError(w, http.StatusInternalServerError, "internal error", err.Error())
		return
	}

	resources := make([]itemResource, 0, len(items))
	for _, i := range items {
		resources = append(resources, toItemResource(i))
	}

	httputil.WriteJSONAPI(w, http.StatusOK, map[string]any{"data": resources})
}

func (h *ItemsHandler) Create(w http.ResponseWriter, r *http.Request) {
	if r.Header.Get("Content-Type") != "application/vnd.api+json" {
		httputil.WriteJSONAPIError(w, http.StatusUnsupportedMediaType, "unsupported media type", "content-type must be application/vnd.api+json")
		return
	}

	var req createItemDocument
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteJSONAPIError(w, http.StatusBadRequest, "invalid request", "request body must be valid JSON:API")
		return
	}

	if req.Data.Type != itemType {
		httputil.WriteJSONAPIError(w, http.StatusConflict, "invalid type", "data.type must be items")
		return
	}

	bestBefore, err := time.Parse(time.DateOnly, req.Data.Attributes.BestBefore)
	if err != nil {
		httputil.WriteJSONAPIError(w, http.StatusBadRequest, "invalid best_before", "best_before must use YYYY-MM-DD")
		return
	}

	created, err := h.service.Create(r.Context(), service.CreateItemInput{
		Name:          req.Data.Attributes.Name,
		BestBefore:    bestBefore,
		ContentAmount: req.Data.Attributes.ContentAmount,
		ContentUnit:   req.Data.Attributes.ContentUnit,
		PictureKey:    req.Data.Attributes.PictureKey,
		Comment:       req.Data.Attributes.Comment,
	})
	if err != nil {
		httputil.WriteJSONAPIError(w, http.StatusBadRequest, "validation error", err.Error())
		return
	}

	httputil.WriteJSONAPI(w, http.StatusCreated, map[string]any{"data": toItemResource(created)})
}
