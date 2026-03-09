package memory

import (
	"context"
	"slices"
	"sync"
	"time"

	"github.com/klausmeyer/pantry/backend/internal/domain/item"
	"github.com/klausmeyer/pantry/backend/internal/repository"
)

type ItemRepository struct {
	mu    sync.RWMutex
	items []item.Item
}

func NewItemRepository() *ItemRepository {
	return &ItemRepository{items: make([]item.Item, 0)}
}

func (r *ItemRepository) Create(_ context.Context, i item.Item) (item.Item, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.items = append(r.items, i)
	return i, nil
}

func (r *ItemRepository) List(_ context.Context, input repository.ListItemsInput) ([]item.Item, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	itemsCopy := make([]item.Item, len(r.items))
	copy(itemsCopy, r.items)

	slices.SortFunc(itemsCopy, func(a, b item.Item) int {
		var cmp int
		switch input.SortBy {
		case repository.ItemSortByName:
			cmp = compareString(a.Name, b.Name)
		case repository.ItemSortByBestBefore:
			cmp = compareTime(a.BestBefore, b.BestBefore)
		case repository.ItemSortByCreatedAt:
			cmp = compareTime(a.CreatedAt, b.CreatedAt)
		case repository.ItemSortByUpdatedAt:
			cmp = compareTime(a.UpdatedAt, b.UpdatedAt)
		default:
			cmp = compareString(a.ID, b.ID)
		}

		if input.SortOrder == repository.SortOrderDesc {
			return -cmp
		}
		return cmp
	})

	return itemsCopy, nil
}

func compareString(a, b string) int {
	switch {
	case a < b:
		return -1
	case a > b:
		return 1
	default:
		return 0
	}
}

func compareTime(a, b time.Time) int {
	switch {
	case a.Before(b):
		return -1
	case a.After(b):
		return 1
	default:
		return 0
	}
}
