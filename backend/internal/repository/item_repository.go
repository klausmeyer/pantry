package repository

import (
	"context"
	"errors"

	"github.com/klausmeyer/pantry/backend/internal/domain/item"
)

type ItemSortBy string

const (
	ItemSortByID         ItemSortBy = "id"
	ItemSortByName       ItemSortBy = "name"
	ItemSortByBestBefore ItemSortBy = "best_before"
	ItemSortByCreatedAt  ItemSortBy = "created_at"
	ItemSortByUpdatedAt  ItemSortBy = "updated_at"
)

type SortOrder string

const (
	SortOrderAsc  SortOrder = "asc"
	SortOrderDesc SortOrder = "desc"
)

type ListItemsInput struct {
	Sort []SortField
}

type SortField struct {
	By    ItemSortBy
	Order SortOrder
}

type ItemRepository interface {
	Create(ctx context.Context, i item.Item) (item.Item, error)
	Update(ctx context.Context, i item.Item) (item.Item, error)
	List(ctx context.Context, input ListItemsInput) ([]item.Item, error)
	SoftDelete(ctx context.Context, id string) error
}

var ErrNotFound = errors.New("item not found")
