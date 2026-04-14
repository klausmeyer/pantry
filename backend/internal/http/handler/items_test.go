package handler

import (
	"net/http/httptest"
	"net/url"
	"testing"
	"time"

	"github.com/klausmeyer/pantry/backend/internal/domain/item"
	"github.com/klausmeyer/pantry/backend/internal/repository"
)

func TestParseListItemsInput_Defaults(t *testing.T) {
	req := httptest.NewRequest("GET", "/items", nil)

	input, err := parseListItemsInput(req)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if len(input.Sort) != 1 || input.Sort[0].By != repository.ItemSortByID || input.Sort[0].Order != repository.SortOrderAsc {
		t.Fatalf("unexpected default sort: %#v", input.Sort)
	}
	if input.Search != "" {
		t.Fatalf("expected empty search, got %q", input.Search)
	}
	if input.ImageFilter != repository.ImageFilterAll {
		t.Fatalf("expected image filter all, got %q", input.ImageFilter)
	}
}

func TestParseListItemsInput_SortSearchFilter(t *testing.T) {
	query := url.Values{}
	query.Set("sort", "-best_before,name")
	query.Set("q", "#Milk")
	query.Set("filter[has_image]", "true")

	req := httptest.NewRequest("GET", "/items?"+query.Encode(), nil)

	input, err := parseListItemsInput(req)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if input.Search != "Milk" {
		t.Fatalf("expected search to strip #, got %q", input.Search)
	}
	if input.ImageFilter != repository.ImageFilterWith {
		t.Fatalf("expected image filter with, got %q", input.ImageFilter)
	}
	if len(input.Sort) != 2 {
		t.Fatalf("expected two sort fields, got %#v", input.Sort)
	}
	if input.Sort[0].By != repository.ItemSortByBestBefore || input.Sort[0].Order != repository.SortOrderDesc {
		t.Fatalf("unexpected first sort: %#v", input.Sort[0])
	}
	if input.Sort[1].By != repository.ItemSortByName || input.Sort[1].Order != repository.SortOrderAsc {
		t.Fatalf("unexpected second sort: %#v", input.Sort[1])
	}
}

func TestParseListItemsInput_InvalidSort(t *testing.T) {
	req := httptest.NewRequest("GET", "/items?sort=name,", nil)
	_, err := parseListItemsInput(req)
	if err == nil {
		t.Fatalf("expected error for empty sort token")
	}
	if err != errInvalidSort {
		t.Fatalf("expected errInvalidSort, got %v", err)
	}
}

func TestParseListItemsInput_InvalidFilter(t *testing.T) {
	req := httptest.NewRequest("GET", "/items?filter[has_image]=maybe", nil)
	_, err := parseListItemsInput(req)
	if err == nil {
		t.Fatalf("expected error for invalid filter")
	}
	if err != errInvalidImageFilter {
		t.Fatalf("expected errInvalidImageFilter, got %v", err)
	}
}

func TestToItemResource_FormatsTimes(t *testing.T) {
	bestBefore := time.Date(2025, time.January, 2, 0, 0, 0, 0, time.UTC)
	createdAt := time.Date(2025, time.January, 3, 4, 5, 6, 0, time.UTC)
	updatedAt := time.Date(2025, time.January, 4, 7, 8, 9, 0, time.UTC)

	resource := toItemResource(item.Item{
		ID:            "123",
		InventoryTag:  "ABCD",
		Name:          "Beans",
		BestBefore:    bestBefore,
		ContentAmount: 2,
		ContentUnit:   item.UnitGrams,
		Packaging:     item.PackagingCan,
		CreatedAt:     createdAt,
		UpdatedAt:     updatedAt,
	})

	if resource.Attributes.BestBefore != "2025-01-02" {
		t.Fatalf("expected best_before formatted, got %q", resource.Attributes.BestBefore)
	}
	if resource.Attributes.CreatedAt != "2025-01-03T04:05:06Z" {
		t.Fatalf("expected created_at formatted, got %q", resource.Attributes.CreatedAt)
	}
	if resource.Attributes.UpdatedAt != "2025-01-04T07:08:09Z" {
		t.Fatalf("expected updated_at formatted, got %q", resource.Attributes.UpdatedAt)
	}
}
