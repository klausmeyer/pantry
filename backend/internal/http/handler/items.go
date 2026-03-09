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
	errInvalidSort = errors.New("sort must use fields id, name, best_before, created_at, updated_at (prefix with '-' for desc)")
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
	Packaging     string  `json:"packaging"`
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
	Name          string         `json:"name"`
	BestBefore    string         `json:"best_before"`
	ContentAmount float64        `json:"content_amount"`
	ContentUnit   item.Unit      `json:"content_unit"`
	Packaging     item.Packaging `json:"packaging"`
	PictureKey    string         `json:"picture_key"`
	Comment       *string        `json:"comment"`
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
			Packaging:     string(i.Packaging),
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
	sortRaw := strings.TrimSpace(strings.ToLower(r.URL.Query().Get("sort")))
	if sortRaw == "" {
		return service.ListItemsInput{
			Sort: []repository.SortField{
				{By: repository.ItemSortByID, Order: repository.SortOrderAsc},
			},
		}, nil
	}

	parts := strings.Split(sortRaw, ",")
	sort := make([]repository.SortField, 0, len(parts))
	for _, part := range parts {
		token := strings.TrimSpace(part)
		if token == "" {
			return service.ListItemsInput{}, errInvalidSort
		}

		order := repository.SortOrderAsc
		if strings.HasPrefix(token, "-") {
			order = repository.SortOrderDesc
			token = strings.TrimPrefix(token, "-")
		}

		var by repository.ItemSortBy
		switch token {
		case "id":
			by = repository.ItemSortByID
		case "name":
			by = repository.ItemSortByName
		case "best_before", "best-before":
			by = repository.ItemSortByBestBefore
		case "created_at", "created-at":
			by = repository.ItemSortByCreatedAt
		case "updated_at", "updated-at":
			by = repository.ItemSortByUpdatedAt
		default:
			return service.ListItemsInput{}, errInvalidSort
		}

		sort = append(sort, repository.SortField{By: by, Order: order})
	}

	return service.ListItemsInput{Sort: sort}, nil
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
		Packaging:     req.Data.Attributes.Packaging,
		PictureKey:    req.Data.Attributes.PictureKey,
		Comment:       req.Data.Attributes.Comment,
	})
	if err != nil {
		httputil.WriteJSONAPIError(w, http.StatusBadRequest, "validation error", err.Error())
		return
	}

	httputil.WriteJSONAPI(w, http.StatusCreated, map[string]any{"data": toItemResource(created)})
}

func (h *ItemsHandler) Delete(w http.ResponseWriter, r *http.Request) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		httputil.WriteJSONAPIError(w, http.StatusBadRequest, "invalid id", "id path parameter is required")
		return
	}

	if err := h.service.SoftDelete(r.Context(), id); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			httputil.WriteJSONAPIError(w, http.StatusNotFound, "not found", "item not found")
			return
		}
		httputil.WriteJSONAPIError(w, http.StatusInternalServerError, "internal error", err.Error())
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
