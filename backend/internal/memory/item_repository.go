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

	itemsCopy := make([]item.Item, 0, len(r.items))
	for _, stored := range r.items {
		if stored.DeletedAt != nil {
			continue
		}
		itemsCopy = append(itemsCopy, stored)
	}

	slices.SortFunc(itemsCopy, func(a, b item.Item) int {
		for _, sortField := range input.Sort {
			cmp := compareBySortField(a, b, sortField.By)
			if cmp == 0 {
				continue
			}
			if sortField.Order == repository.SortOrderDesc {
				return -cmp
			}
			return cmp
		}

		return compareString(a.ID, b.ID)
	})

	return itemsCopy, nil
}

func (r *ItemRepository) SoftDelete(_ context.Context, id string) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	now := time.Now().UTC()
	for index, stored := range r.items {
		if stored.ID != id {
			continue
		}
		if stored.DeletedAt != nil {
			return repository.ErrNotFound
		}
		stored.DeletedAt = &now
		stored.UpdatedAt = now
		r.items[index] = stored
		return nil
	}

	return repository.ErrNotFound
}

func compareBySortField(a, b item.Item, sortBy repository.ItemSortBy) int {
	switch sortBy {
	case repository.ItemSortByName:
		return compareString(a.Name, b.Name)
	case repository.ItemSortByBestBefore:
		return compareTime(a.BestBefore, b.BestBefore)
	case repository.ItemSortByCreatedAt:
		return compareTime(a.CreatedAt, b.CreatedAt)
	case repository.ItemSortByUpdatedAt:
		return compareTime(a.UpdatedAt, b.UpdatedAt)
	default:
		return compareString(a.ID, b.ID)
	}
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
