package postgres

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"slices"
	"strings"
	"time"

	"github.com/klausmeyer/pantry/backend/internal/domain/item"
	"github.com/klausmeyer/pantry/backend/internal/repository"
)

const createItemsTableSQL = `
CREATE TABLE IF NOT EXISTS items (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  best_before DATE NOT NULL,
  content_amount DOUBLE PRECISION NOT NULL,
  content_unit TEXT NOT NULL,
  packaging TEXT NOT NULL DEFAULT 'other',
  picture_key TEXT NOT NULL,
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  deleted_at TIMESTAMPTZ
);
`

const ensurePackagingColumnSQL = `
ALTER TABLE items
ADD COLUMN IF NOT EXISTS packaging TEXT NOT NULL DEFAULT 'other';
`

const ensureDeletedAtColumnSQL = `
ALTER TABLE items
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
`

type ItemRepository struct {
	db *sql.DB
}

func NewItemRepository(db *sql.DB) (*ItemRepository, error) {
	repo := &ItemRepository{db: db}

	if err := repo.ensureSchema(context.Background()); err != nil {
		return nil, err
	}

	return repo, nil
}

func (r *ItemRepository) ensureSchema(ctx context.Context) error {
	if _, err := r.db.ExecContext(ctx, createItemsTableSQL); err != nil {
		return fmt.Errorf("ensure items table: %w", err)
	}
	if _, err := r.db.ExecContext(ctx, ensurePackagingColumnSQL); err != nil {
		return fmt.Errorf("ensure packaging column: %w", err)
	}
	if _, err := r.db.ExecContext(ctx, ensureDeletedAtColumnSQL); err != nil {
		return fmt.Errorf("ensure deleted_at column: %w", err)
	}
	return nil
}

func (r *ItemRepository) Create(ctx context.Context, i item.Item) (item.Item, error) {
	const query = `
INSERT INTO items (
  id, name, best_before, content_amount, content_unit, packaging, picture_key, comment, created_at, updated_at
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10);
`

	if _, err := r.db.ExecContext(
		ctx,
		query,
		i.ID,
		i.Name,
		i.BestBefore,
		i.ContentAmount,
		i.ContentUnit,
		i.Packaging,
		i.PictureKey,
		i.Comment,
		i.CreatedAt,
		i.UpdatedAt,
	); err != nil {
		return item.Item{}, fmt.Errorf("insert item: %w", err)
	}

	return i, nil
}

func (r *ItemRepository) Update(ctx context.Context, i item.Item) (item.Item, error) {
	const query = `
UPDATE items
SET
  name = $2,
  best_before = $3,
  content_amount = $4,
  content_unit = $5,
  packaging = $6,
  picture_key = $7,
  comment = $8,
  updated_at = NOW()
WHERE id = $1 AND deleted_at IS NULL
RETURNING created_at, updated_at;
`

	var createdAt time.Time
	var updatedAt time.Time
	if err := r.db.QueryRowContext(
		ctx,
		query,
		i.ID,
		i.Name,
		i.BestBefore,
		i.ContentAmount,
		i.ContentUnit,
		i.Packaging,
		i.PictureKey,
		i.Comment,
	).Scan(&createdAt, &updatedAt); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return item.Item{}, repository.ErrNotFound
		}
		return item.Item{}, fmt.Errorf("update item: %w", err)
	}

	i.CreatedAt = createdAt
	i.UpdatedAt = updatedAt
	return i, nil
}

func (r *ItemRepository) List(ctx context.Context, input repository.ListItemsInput) ([]item.Item, error) {
	orderBy := make([]string, 0, len(input.Sort)+1)
	for _, sortField := range input.Sort {
		sortColumn, ok := sortColumns[sortField.By]
		if !ok {
			continue
		}

		sortOrder := "ASC"
		if sortField.Order == repository.SortOrderDesc {
			sortOrder = "DESC"
		}

		orderBy = append(orderBy, fmt.Sprintf("%s %s", sortColumn, sortOrder))
	}
	if len(orderBy) == 0 {
		orderBy = append(orderBy, "id ASC")
	}
	if !slices.Contains(orderBy, "id ASC") && !slices.Contains(orderBy, "id DESC") {
		orderBy = append(orderBy, "id ASC")
	}

	query := fmt.Sprintf(`
SELECT id, name, best_before, content_amount, content_unit, packaging, picture_key, comment, created_at, updated_at
FROM items
WHERE deleted_at IS NULL
ORDER BY %s;
`, strings.Join(orderBy, ", "))

	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("list items: %w", err)
	}
	defer rows.Close()

	items := make([]item.Item, 0)
	for rows.Next() {
		var (
			i           item.Item
			contentUnit string
			comment     sql.NullString
		)

		if err := rows.Scan(
			&i.ID,
			&i.Name,
			&i.BestBefore,
			&i.ContentAmount,
			&contentUnit,
			&i.Packaging,
			&i.PictureKey,
			&comment,
			&i.CreatedAt,
			&i.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan item: %w", err)
		}

		i.ContentUnit = item.Unit(contentUnit)
		if comment.Valid {
			i.Comment = &comment.String
		}

		items = append(items, i)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate items: %w", err)
	}

	return items, nil
}

func (r *ItemRepository) SoftDelete(ctx context.Context, id string) error {
	const query = `
UPDATE items
SET deleted_at = NOW(), updated_at = NOW()
WHERE id = $1 AND deleted_at IS NULL;
`

	result, err := r.db.ExecContext(ctx, query, id)
	if err != nil {
		return fmt.Errorf("soft delete item: %w", err)
	}

	affected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("soft delete item rows affected: %w", err)
	}
	if affected == 0 {
		return repository.ErrNotFound
	}

	return nil
}

var sortColumns = map[repository.ItemSortBy]string{
	repository.ItemSortByID:         "id",
	repository.ItemSortByName:       "name",
	repository.ItemSortByBestBefore: "best_before",
	repository.ItemSortByCreatedAt:  "created_at",
	repository.ItemSortByUpdatedAt:  "updated_at",
}
