package postgres

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/klausmeyer/pantry/backend/internal/domain/item"
)

const createItemsTableSQL = `
CREATE TABLE IF NOT EXISTS items (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  best_before DATE NOT NULL,
  content_amount DOUBLE PRECISION NOT NULL,
  content_unit TEXT NOT NULL,
  picture_key TEXT NOT NULL,
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);
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
	return nil
}

func (r *ItemRepository) Create(ctx context.Context, i item.Item) (item.Item, error) {
	const query = `
INSERT INTO items (
  id, name, best_before, content_amount, content_unit, picture_key, comment, created_at, updated_at
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9);
`

	if _, err := r.db.ExecContext(
		ctx,
		query,
		i.ID,
		i.Name,
		i.BestBefore,
		i.ContentAmount,
		i.ContentUnit,
		i.PictureKey,
		i.Comment,
		i.CreatedAt,
		i.UpdatedAt,
	); err != nil {
		return item.Item{}, fmt.Errorf("insert item: %w", err)
	}

	return i, nil
}

func (r *ItemRepository) List(ctx context.Context) ([]item.Item, error) {
	const query = `
SELECT id, name, best_before, content_amount, content_unit, picture_key, comment, created_at, updated_at
FROM items
ORDER BY created_at DESC;
`

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
