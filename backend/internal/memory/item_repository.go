package memory

import (
	"context"
	"sync"

	"github.com/klausmeyer/pantry/backend/internal/domain/item"
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

func (r *ItemRepository) List(_ context.Context) ([]item.Item, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	itemsCopy := make([]item.Item, len(r.items))
	copy(itemsCopy, r.items)
	return itemsCopy, nil
}
