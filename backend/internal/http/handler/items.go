package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/klausmeyer/pantry/backend/internal/domain/item"
	"github.com/klausmeyer/pantry/backend/internal/repository"
	"github.com/klausmeyer/pantry/backend/internal/service"
	"github.com/klausmeyer/pantry/backend/pkg/httputil"
)

const itemType = "items"

var (
	errInvalidSortBy    = errors.New("sort_by must be one of id, name, best_before, created_at, updated_at")
	errInvalidSortOrder = errors.New("sort_order must be one of asc, desc")
)

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
	listInput, err := parseListItemsInput(r)
	if err != nil {
		httputil.WriteJSONAPIError(w, http.StatusBadRequest, "invalid sorting", err.Error())
		return
	}

	items, err := h.service.List(r.Context(), listInput)
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

func parseListItemsInput(r *http.Request) (service.ListItemsInput, error) {
	sortByRaw := strings.TrimSpace(strings.ToLower(r.URL.Query().Get("sort_by")))
	sortOrderRaw := strings.TrimSpace(strings.ToLower(r.URL.Query().Get("sort_order")))

	input := service.ListItemsInput{
		SortBy:    repository.ItemSortByID,
		SortOrder: repository.SortOrderAsc,
	}

	if sortByRaw != "" {
		switch sortByRaw {
		case "id":
			input.SortBy = repository.ItemSortByID
		case "name":
			input.SortBy = repository.ItemSortByName
		case "best_before", "best-before":
			input.SortBy = repository.ItemSortByBestBefore
		case "created_at", "created-at":
			input.SortBy = repository.ItemSortByCreatedAt
		case "updated_at", "updated-at":
			input.SortBy = repository.ItemSortByUpdatedAt
		default:
			return service.ListItemsInput{}, errInvalidSortBy
		}
	}

	if sortOrderRaw != "" {
		switch sortOrderRaw {
		case "asc":
			input.SortOrder = repository.SortOrderAsc
		case "desc":
			input.SortOrder = repository.SortOrderDesc
		default:
			return service.ListItemsInput{}, errInvalidSortOrder
		}
	}

	return input, nil
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
