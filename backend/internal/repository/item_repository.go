package repository

import (
	"context"

	"github.com/klausmeyer/pantry/backend/internal/domain/item"
)

type ItemRepository interface {
	Create(ctx context.Context, i item.Item) (item.Item, error)
	List(ctx context.Context) ([]item.Item, error)
}
