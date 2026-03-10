package service

import (
	"context"
	"errors"
	"log"
	"strings"
	"time"

	"github.com/klausmeyer/pantry/backend/internal/domain/item"
	"github.com/klausmeyer/pantry/backend/internal/id"
	"github.com/klausmeyer/pantry/backend/internal/repository"
)

type ItemService struct {
	repo           repository.ItemRepository
	ids            *id.Generator
	pictureRemover PictureRemover
}

type CreateItemInput struct {
	Name          string
	BestBefore    time.Time
	ContentAmount float64
	ContentUnit   item.Unit
	Packaging     item.Packaging
	PictureKey    *string
	Comment       *string
}

type ListItemsInput struct {
	Sort   []repository.SortField
	Search string
}

type PictureRemover interface {
	Delete(ctx context.Context, key string) error
}

func NewItemService(repo repository.ItemRepository, ids *id.Generator, pictureRemover PictureRemover) *ItemService {
	return &ItemService{repo: repo, ids: ids, pictureRemover: pictureRemover}
}

func (s *ItemService) Create(ctx context.Context, input CreateItemInput) (item.Item, error) {
	if err := validateCreateOrUpdateInput(input); err != nil {
		return item.Item{}, err
	}

	now := time.Now().UTC()
	created := item.Item{
		ID:            s.ids.New(),
		Name:          strings.TrimSpace(input.Name),
		BestBefore:    input.BestBefore,
		ContentAmount: input.ContentAmount,
		ContentUnit:   input.ContentUnit,
		Packaging:     input.Packaging,
		PictureKey:    normalizePictureKey(input.PictureKey),
		Comment:       input.Comment,
		CreatedAt:     now,
		UpdatedAt:     now,
	}

	return s.repo.Create(ctx, created)
}

func (s *ItemService) Update(ctx context.Context, id string, input CreateItemInput) (item.Item, error) {
	if strings.TrimSpace(id) == "" {
		return item.Item{}, errors.New("id is required")
	}
	if err := validateCreateOrUpdateInput(input); err != nil {
		return item.Item{}, err
	}

	existing, err := s.repo.GetByID(ctx, strings.TrimSpace(id))
	if err != nil {
		return item.Item{}, err
	}

	now := time.Now().UTC()
	updated := item.Item{
		ID:            strings.TrimSpace(id),
		Name:          strings.TrimSpace(input.Name),
		BestBefore:    input.BestBefore,
		ContentAmount: input.ContentAmount,
		ContentUnit:   input.ContentUnit,
		Packaging:     input.Packaging,
		PictureKey:    normalizePictureKey(input.PictureKey),
		Comment:       input.Comment,
		UpdatedAt:     now,
	}

	updated, err = s.repo.Update(ctx, updated)
	if err != nil {
		return item.Item{}, err
	}

	s.cleanupOldPicture(ctx, existing.PictureKey, updated.PictureKey)

	return updated, nil
}

func validateCreateOrUpdateInput(input CreateItemInput) error {
	if strings.TrimSpace(input.Name) == "" {
		return errors.New("name is required")
	}
	if input.ContentAmount <= 0 {
		return errors.New("content_amount must be greater than 0")
	}
	if input.ContentUnit == "" {
		return errors.New("content_unit is required")
	}
	switch input.Packaging {
	case item.PackagingCan, item.PackagingBox, item.PackagingBag, item.PackagingJar, item.PackagingOther:
	default:
		return errors.New("packaging must be one of can, box, bag, jar, other")
	}
	return nil
}

func normalizePictureKey(key *string) *string {
	if key == nil {
		return nil
	}
	trimmed := strings.TrimSpace(*key)
	if trimmed == "" {
		return nil
	}
	return &trimmed
}

func (s *ItemService) cleanupOldPicture(ctx context.Context, previous, current *string) {
	if s.pictureRemover == nil || previous == nil {
		return
	}
	if current != nil && *current == *previous {
		return
	}
	if err := s.pictureRemover.Delete(ctx, *previous); err != nil {
		log.Printf("failed to delete picture key=%s: %v", *previous, err)
	}
}

func (s *ItemService) List(ctx context.Context, input ListItemsInput) ([]item.Item, error) {
	return s.repo.List(ctx, repository.ListItemsInput{
		Sort:   normalizeSort(input.Sort),
		Search: strings.TrimSpace(input.Search),
	})
}

func (s *ItemService) SoftDelete(ctx context.Context, id string) error {
	if strings.TrimSpace(id) == "" {
		return errors.New("id is required")
	}
	return s.repo.SoftDelete(ctx, strings.TrimSpace(id))
}

func normalizeSort(sort []repository.SortField) []repository.SortField {
	if len(sort) == 0 {
		return []repository.SortField{
			{By: repository.ItemSortByID, Order: repository.SortOrderAsc},
		}
	}

	normalized := make([]repository.SortField, 0, len(sort))
	for _, field := range sort {
		by := field.By
		switch by {
		case repository.ItemSortByID,
			repository.ItemSortByName,
			repository.ItemSortByBestBefore,
			repository.ItemSortByCreatedAt,
			repository.ItemSortByUpdatedAt:
		default:
			continue
		}

		order := field.Order
		if order != repository.SortOrderAsc && order != repository.SortOrderDesc {
			order = repository.SortOrderAsc
		}

		normalized = append(normalized, repository.SortField{By: by, Order: order})
	}

	if len(normalized) == 0 {
		return []repository.SortField{
			{By: repository.ItemSortByID, Order: repository.SortOrderAsc},
		}
	}

	return normalized
}
