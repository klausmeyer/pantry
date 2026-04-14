package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/klausmeyer/pantry/backend/internal/domain/item"
	"github.com/klausmeyer/pantry/backend/internal/id"
	"github.com/klausmeyer/pantry/backend/internal/repository"
)

type fakeItemRepo struct {
	createFn          func(ctx context.Context, i item.Item) (item.Item, error)
	updateFn          func(ctx context.Context, i item.Item) (item.Item, error)
	getByIDFn         func(ctx context.Context, id string) (item.Item, error)
	listFn            func(ctx context.Context, input repository.ListItemsInput) ([]item.Item, error)
	softDeleteFn      func(ctx context.Context, id string) error
	nextInventoryTagFn func(ctx context.Context) (int64, error)

	created      item.Item
	updated      item.Item
	listInput    repository.ListItemsInput
	softDeleteID string
}

func (f *fakeItemRepo) Create(ctx context.Context, i item.Item) (item.Item, error) {
	f.created = i
	if f.createFn != nil {
		return f.createFn(ctx, i)
	}
	return i, nil
}

func (f *fakeItemRepo) Update(ctx context.Context, i item.Item) (item.Item, error) {
	f.updated = i
	if f.updateFn != nil {
		return f.updateFn(ctx, i)
	}
	return i, nil
}

func (f *fakeItemRepo) GetByID(ctx context.Context, id string) (item.Item, error) {
	if f.getByIDFn != nil {
		return f.getByIDFn(ctx, id)
	}
	return item.Item{}, errors.New("GetByID not implemented")
}

func (f *fakeItemRepo) List(ctx context.Context, input repository.ListItemsInput) ([]item.Item, error) {
	f.listInput = input
	if f.listFn != nil {
		return f.listFn(ctx, input)
	}
	return nil, nil
}

func (f *fakeItemRepo) SoftDelete(ctx context.Context, id string) error {
	f.softDeleteID = id
	if f.softDeleteFn != nil {
		return f.softDeleteFn(ctx, id)
	}
	return nil
}

func (f *fakeItemRepo) NextInventoryTag(ctx context.Context) (int64, error) {
	if f.nextInventoryTagFn != nil {
		return f.nextInventoryTagFn(ctx)
	}
	return 0, errors.New("NextInventoryTag not implemented")
}

type fakePictureRemover struct {
	deletedKey string
	called     bool
}

func (f *fakePictureRemover) Delete(ctx context.Context, key string) error {
	f.deletedKey = key
	f.called = true
	return nil
}

func TestItemServiceCreate_NormalizesAndStores(t *testing.T) {
	repo := &fakeItemRepo{}
	repo.nextInventoryTagFn = func(ctx context.Context) (int64, error) {
		return 42, nil
	}

	svc := NewItemService(repo, id.NewGenerator(), nil)

	picture := "  pic.jpg "
	comment := "note"
	bestBefore := time.Date(2025, time.March, 10, 0, 0, 0, 0, time.UTC)

	created, err := svc.Create(context.Background(), CreateItemInput{
		Name:          "  Oats  ",
		BestBefore:    bestBefore,
		ContentAmount: 1.5,
		ContentUnit:   item.UnitGrams,
		Packaging:     item.PackagingBag,
		PictureKey:    &picture,
		Comment:       &comment,
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if created.ID == "" {
		t.Fatalf("expected ID to be set")
	}
	if created.InventoryTag != id.EncodeCrockfordBase32(42, id.InventoryTagLength) {
		t.Fatalf("unexpected inventory tag: %s", created.InventoryTag)
	}
	if created.Name != "Oats" {
		t.Fatalf("expected name to be trimmed, got %q", created.Name)
	}
	if created.PictureKey == nil || *created.PictureKey != "pic.jpg" {
		t.Fatalf("expected picture key to be trimmed, got %#v", created.PictureKey)
	}
	if created.CreatedAt.IsZero() || created.UpdatedAt.IsZero() {
		t.Fatalf("expected timestamps to be set")
	}
	if !created.CreatedAt.Equal(created.UpdatedAt) {
		t.Fatalf("expected created and updated times to match")
	}
}

func TestItemServiceCreate_InvalidInput(t *testing.T) {
	repo := &fakeItemRepo{}
	svc := NewItemService(repo, id.NewGenerator(), nil)

	_, err := svc.Create(context.Background(), CreateItemInput{
		Name:          "",
		BestBefore:    time.Now(),
		ContentAmount: 1,
		ContentUnit:   item.UnitGrams,
		Packaging:     item.PackagingBag,
	})
	if err == nil {
		t.Fatalf("expected validation error")
	}
}

func TestItemServiceUpdate_DeletesOldPictureOnChange(t *testing.T) {
	repo := &fakeItemRepo{}
	repo.getByIDFn = func(ctx context.Context, id string) (item.Item, error) {
		prev := "old.png"
		return item.Item{ID: id, InventoryTag: "TAG1", PictureKey: &prev}, nil
	}
	repo.updateFn = func(ctx context.Context, i item.Item) (item.Item, error) {
		return i, nil
	}

	remover := &fakePictureRemover{}
	svc := NewItemService(repo, id.NewGenerator(), remover)

	newPic := "new.png"
	_, err := svc.Update(context.Background(), " 123 ", CreateItemInput{
		Name:          "Beans",
		BestBefore:    time.Now(),
		ContentAmount: 2,
		ContentUnit:   item.UnitGrams,
		Packaging:     item.PackagingCan,
		PictureKey:    &newPic,
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if !remover.called || remover.deletedKey != "old.png" {
		t.Fatalf("expected old picture to be deleted, got called=%v key=%q", remover.called, remover.deletedKey)
	}
}

func TestItemServiceUpdate_DoesNotDeleteWhenSamePicture(t *testing.T) {
	repo := &fakeItemRepo{}
	repo.getByIDFn = func(ctx context.Context, id string) (item.Item, error) {
		prev := "same.png"
		return item.Item{ID: id, InventoryTag: "TAG1", PictureKey: &prev}, nil
	}
	repo.updateFn = func(ctx context.Context, i item.Item) (item.Item, error) {
		return i, nil
	}

	remover := &fakePictureRemover{}
	svc := NewItemService(repo, id.NewGenerator(), remover)

	same := " same.png "
	_, err := svc.Update(context.Background(), "123", CreateItemInput{
		Name:          "Beans",
		BestBefore:    time.Now(),
		ContentAmount: 2,
		ContentUnit:   item.UnitGrams,
		Packaging:     item.PackagingCan,
		PictureKey:    &same,
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if remover.called {
		t.Fatalf("expected remover not to be called")
	}
}

func TestItemServiceList_NormalizesSortAndFilter(t *testing.T) {
	repo := &fakeItemRepo{}
	repo.listFn = func(ctx context.Context, input repository.ListItemsInput) ([]item.Item, error) {
		return nil, nil
	}

	svc := NewItemService(repo, id.NewGenerator(), nil)
	_, err := svc.List(context.Background(), ListItemsInput{
		Sort: []repository.SortField{{By: "bad", Order: "down"}},
		Search:      "  oats ",
		ImageFilter: "unknown",
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if len(repo.listInput.Sort) != 1 || repo.listInput.Sort[0].By != repository.ItemSortByID || repo.listInput.Sort[0].Order != repository.SortOrderAsc {
		t.Fatalf("expected default sort to be applied, got %#v", repo.listInput.Sort)
	}
	if repo.listInput.Search != "oats" {
		t.Fatalf("expected search to be trimmed, got %q", repo.listInput.Search)
	}
	if repo.listInput.ImageFilter != repository.ImageFilterAll {
		t.Fatalf("expected image filter to default to all, got %q", repo.listInput.ImageFilter)
	}
}

func TestItemServiceSoftDelete_RequiresID(t *testing.T) {
	repo := &fakeItemRepo{}
	svc := NewItemService(repo, id.NewGenerator(), nil)

	if err := svc.SoftDelete(context.Background(), " "); err == nil {
		t.Fatalf("expected error for empty id")
	}
}
