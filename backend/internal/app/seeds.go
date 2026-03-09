package app

import (
	"context"
	"fmt"
	"time"

	"github.com/klausmeyer/pantry/backend/internal/domain/item"
	"github.com/klausmeyer/pantry/backend/internal/repository"
	"github.com/klausmeyer/pantry/backend/internal/service"
)

func seedDevelopmentItems(ctx context.Context, svc *service.ItemService, count int) error {
	existing, err := svc.List(ctx, service.ListItemsInput{
		Sort: []repository.SortField{
			{By: repository.ItemSortByID, Order: repository.SortOrderAsc},
		},
	})
	if err != nil {
		return fmt.Errorf("list items before seeding: %w", err)
	}
	if len(existing) > 0 {
		return nil
	}

	names := seedNames(count)
	units := []item.Unit{item.UnitGrams, item.UnitML, item.UnitL}
	startDate := time.Now().UTC().AddDate(0, -2, 0)

	for i := 0; i < count; i++ {
		bestBefore := startDate.AddDate(0, 0, i)
		var comment *string
		if i%4 == 0 {
			text := fmt.Sprintf("Seeded item #%03d", i+1)
			comment = &text
		}

		if _, err := svc.Create(ctx, service.CreateItemInput{
			Name:          names[i],
			BestBefore:    bestBefore,
			ContentAmount: float64(100 + (i % 20 * 25)),
			ContentUnit:   units[i%len(units)],
			PictureKey:    fmt.Sprintf("items/seed-%03d.png", i+1),
			Comment:       comment,
		}); err != nil {
			return fmt.Errorf("create seed item %d: %w", i+1, err)
		}
	}

	return nil
}

func seedNames(count int) []string {
	adjectives := []string{
		"Fresh", "Golden", "Crispy", "Smoky", "Tender",
		"Rustic", "Savory", "Creamy", "Toasted", "Zesty",
	}
	foods := []string{
		"Rice", "Pasta", "Beans", "Lentils", "Oats",
		"Tomatoes", "Peas", "Corn", "Milk", "Broth",
	}

	names := make([]string, 0, count)
	for _, adjective := range adjectives {
		for _, food := range foods {
			names = append(names, adjective+" "+food)
			if len(names) == count {
				return names
			}
		}
	}

	for len(names) < count {
		names = append(names, fmt.Sprintf("Pantry Item %03d", len(names)+1))
	}

	return names
}
