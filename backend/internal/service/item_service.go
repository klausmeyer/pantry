package service

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/klausmeyer/pantry/backend/internal/domain/item"
	"github.com/klausmeyer/pantry/backend/internal/id"
	"github.com/klausmeyer/pantry/backend/internal/repository"
)

type ItemService struct {
	repo repository.ItemRepository
	ids  *id.Generator
}

type CreateItemInput struct {
	Name          string
	BestBefore    time.Time
	ContentAmount float64
	ContentUnit   item.Unit
	PictureKey    string
	Comment       *string
}

func NewItemService(repo repository.ItemRepository, ids *id.Generator) *ItemService {
	return &ItemService{repo: repo, ids: ids}
}

func (s *ItemService) Create(ctx context.Context, input CreateItemInput) (item.Item, error) {
	if strings.TrimSpace(input.Name) == "" {
		return item.Item{}, errors.New("name is required")
	}
	if input.ContentAmount <= 0 {
		return item.Item{}, errors.New("content_amount must be greater than 0")
	}
	if input.ContentUnit == "" {
		return item.Item{}, errors.New("content_unit is required")
	}

	now := time.Now().UTC()
	created := item.Item{
		ID:            s.ids.New(),
		Name:          strings.TrimSpace(input.Name),
		BestBefore:    input.BestBefore,
		ContentAmount: input.ContentAmount,
		ContentUnit:   input.ContentUnit,
		PictureKey:    strings.TrimSpace(input.PictureKey),
		Comment:       input.Comment,
		CreatedAt:     now,
		UpdatedAt:     now,
	}

	return s.repo.Create(ctx, created)
}

func (s *ItemService) List(ctx context.Context) ([]item.Item, error) {
	return s.repo.List(ctx)
}
