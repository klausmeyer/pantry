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
	"github.com/klausmeyer/pantry/backend/internal/id"
	"github.com/klausmeyer/pantry/backend/internal/repository"
)

const createItemsTableSQL = `
CREATE EXTENSION IF NOT EXISTS unaccent;

CREATE OR REPLACE FUNCTION items_search_text() RETURNS trigger AS $$
BEGIN
  NEW.search_text := unaccent(lower(coalesce(NEW.name, '') || ' ' || coalesce(NEW.comment, '')));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE SEQUENCE IF NOT EXISTS inventory_tag_seq;

CREATE TABLE IF NOT EXISTS items (
  id TEXT PRIMARY KEY,
  inventory_tag TEXT UNIQUE,
  name TEXT NOT NULL,
  best_before DATE NOT NULL,
  content_amount DOUBLE PRECISION NOT NULL,
  content_unit TEXT NOT NULL,
  packaging TEXT NOT NULL DEFAULT 'other',
  picture_key TEXT,
  comment TEXT,
  search_text TEXT,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  deleted_at TIMESTAMPTZ
);

DROP TRIGGER IF EXISTS items_search_text_trigger ON items;
CREATE TRIGGER items_search_text_trigger
BEFORE INSERT OR UPDATE OF name, comment ON items
FOR EACH ROW
EXECUTE FUNCTION items_search_text();
`

const ensurePackagingColumnSQL = `
ALTER TABLE items
ADD COLUMN IF NOT EXISTS packaging TEXT NOT NULL DEFAULT 'other';
`

const ensureDeletedAtColumnSQL = `
ALTER TABLE items
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
`

const ensureUnaccentExtensionSQL = `
CREATE EXTENSION IF NOT EXISTS unaccent;
`

const ensureSearchTextColumnSQL = `
ALTER TABLE items
ADD COLUMN IF NOT EXISTS search_text TEXT;
`

const ensureSearchTextTriggerSQL = `
CREATE OR REPLACE FUNCTION items_search_text() RETURNS trigger AS $$
BEGIN
  NEW.search_text := unaccent(lower(coalesce(NEW.name, '') || ' ' || coalesce(NEW.comment, '') || ' ' || coalesce(NEW.inventory_tag, '')));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS items_search_text_trigger ON items;
CREATE TRIGGER items_search_text_trigger
BEFORE INSERT OR UPDATE OF name, comment, inventory_tag ON items
FOR EACH ROW
EXECUTE FUNCTION items_search_text();
`

const ensureInventoryTagColumnSQL = `
ALTER TABLE items
ADD COLUMN IF NOT EXISTS inventory_tag TEXT;
`

const ensureInventoryTagSequenceSQL = `
CREATE SEQUENCE IF NOT EXISTS inventory_tag_seq;
`

const ensureInventoryTagUniqueIndexSQL = `
CREATE UNIQUE INDEX IF NOT EXISTS items_inventory_tag_key ON items (inventory_tag);
`

const allowNullPictureKeySQL = `
ALTER TABLE items
ALTER COLUMN picture_key DROP NOT NULL;
`

const normalizeEmptyPictureKeySQL = `
UPDATE items
SET picture_key = NULL
WHERE picture_key = '';
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
	if _, err := r.db.ExecContext(ctx, ensureUnaccentExtensionSQL); err != nil {
		return fmt.Errorf("ensure unaccent extension: %w", err)
	}
	if _, err := r.db.ExecContext(ctx, ensureInventoryTagSequenceSQL); err != nil {
		return fmt.Errorf("ensure inventory tag sequence: %w", err)
	}
	if _, err := r.db.ExecContext(ctx, ensurePackagingColumnSQL); err != nil {
		return fmt.Errorf("ensure packaging column: %w", err)
	}
	if _, err := r.db.ExecContext(ctx, ensureInventoryTagColumnSQL); err != nil {
		return fmt.Errorf("ensure inventory tag column: %w", err)
	}
	if _, err := r.db.ExecContext(ctx, ensureInventoryTagUniqueIndexSQL); err != nil {
		return fmt.Errorf("ensure inventory tag unique index: %w", err)
	}
	if _, err := r.db.ExecContext(ctx, ensureDeletedAtColumnSQL); err != nil {
		return fmt.Errorf("ensure deleted_at column: %w", err)
	}
	if _, err := r.db.ExecContext(ctx, ensureSearchTextColumnSQL); err != nil {
		return fmt.Errorf("ensure search_text column: %w", err)
	}
	if _, err := r.db.ExecContext(ctx, ensureSearchTextTriggerSQL); err != nil {
		return fmt.Errorf("ensure search_text trigger: %w", err)
	}
	if _, err := r.db.ExecContext(ctx, allowNullPictureKeySQL); err != nil {
		return fmt.Errorf("allow null picture_key: %w", err)
	}
	if _, err := r.db.ExecContext(ctx, normalizeEmptyPictureKeySQL); err != nil {
		return fmt.Errorf("normalize picture_key: %w", err)
	}
	if err := r.ensureInventoryTags(ctx); err != nil {
		return fmt.Errorf("ensure inventory tags: %w", err)
	}
	return nil
}

func (r *ItemRepository) Create(ctx context.Context, i item.Item) (item.Item, error) {
	const query = `
INSERT INTO items (
  id, inventory_tag, name, best_before, content_amount, content_unit, packaging, picture_key, comment, created_at, updated_at
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11);
`

	if _, err := r.db.ExecContext(
		ctx,
		query,
		i.ID,
		i.InventoryTag,
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
RETURNING inventory_tag, created_at, updated_at;
`

	var createdAt time.Time
	var updatedAt time.Time
	var inventoryTag sql.NullString
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
	).Scan(&inventoryTag, &createdAt, &updatedAt); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return item.Item{}, repository.ErrNotFound
		}
		return item.Item{}, fmt.Errorf("update item: %w", err)
	}

	if inventoryTag.Valid {
		i.InventoryTag = inventoryTag.String
	}
	i.CreatedAt = createdAt
	i.UpdatedAt = updatedAt
	return i, nil
}

func (r *ItemRepository) GetByID(ctx context.Context, id string) (item.Item, error) {
	const query = `
SELECT id, inventory_tag, name, best_before, content_amount, content_unit, packaging, picture_key, comment, created_at, updated_at
FROM items
WHERE id = $1 AND deleted_at IS NULL;
`

	var (
		i           item.Item
		contentUnit string
		comment     sql.NullString
		pictureKey  sql.NullString
		inventoryTag sql.NullString
	)

	if err := r.db.QueryRowContext(ctx, query, id).Scan(
		&i.ID,
		&inventoryTag,
		&i.Name,
		&i.BestBefore,
		&i.ContentAmount,
		&contentUnit,
		&i.Packaging,
		&pictureKey,
		&comment,
		&i.CreatedAt,
		&i.UpdatedAt,
	); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return item.Item{}, repository.ErrNotFound
		}
		return item.Item{}, fmt.Errorf("get item: %w", err)
	}

	i.ContentUnit = item.Unit(contentUnit)
	if inventoryTag.Valid {
		i.InventoryTag = inventoryTag.String
	}
	if pictureKey.Valid {
		i.PictureKey = &pictureKey.String
	}
	if comment.Valid {
		i.Comment = &comment.String
	}

	return i, nil
}

func (r *ItemRepository) List(ctx context.Context, input repository.ListItemsInput) ([]item.Item, error) {
	whereParts := []string{"deleted_at IS NULL"}
	args := []any{}
	argPos := 1

	if strings.TrimSpace(input.Search) != "" {
		whereParts = append(whereParts, fmt.Sprintf("search_text LIKE unaccent(lower($%d))", argPos))
		args = append(args, "%"+strings.TrimSpace(input.Search)+"%")
		argPos++
	}

	switch input.ImageFilter {
	case repository.ImageFilterWith:
		whereParts = append(whereParts, "picture_key IS NOT NULL")
	case repository.ImageFilterWithout:
		whereParts = append(whereParts, "picture_key IS NULL")
	}

	where := strings.Join(whereParts, " AND ")

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
SELECT id, inventory_tag, name, best_before, content_amount, content_unit, packaging, picture_key, comment, created_at, updated_at
FROM items
WHERE %s
ORDER BY %s;
`, where, strings.Join(orderBy, ", "))

	rows, err := r.db.QueryContext(ctx, query, args...)
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
			pictureKey  sql.NullString
			inventoryTag sql.NullString
		)

		if err := rows.Scan(
			&i.ID,
			&inventoryTag,
			&i.Name,
			&i.BestBefore,
			&i.ContentAmount,
			&contentUnit,
			&i.Packaging,
			&pictureKey,
			&comment,
			&i.CreatedAt,
			&i.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan item: %w", err)
		}

		i.ContentUnit = item.Unit(contentUnit)
		if inventoryTag.Valid {
			i.InventoryTag = inventoryTag.String
		}
		if pictureKey.Valid {
			i.PictureKey = &pictureKey.String
		}
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

func (r *ItemRepository) NextInventoryTag(ctx context.Context) (int64, error) {
	const query = `SELECT nextval('inventory_tag_seq');`

	var next int64
	if err := r.db.QueryRowContext(ctx, query).Scan(&next); err != nil {
		return 0, fmt.Errorf("next inventory tag: %w", err)
	}
	return next, nil
}

func (r *ItemRepository) ensureInventoryTags(ctx context.Context) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin inventory tag backfill: %w", err)
	}
	defer func() {
		_ = tx.Rollback()
	}()

	var needsRebuild bool
	if err := tx.QueryRowContext(ctx, `SELECT EXISTS (SELECT 1 FROM items WHERE inventory_tag LIKE '%0%');`).Scan(&needsRebuild); err != nil {
		return fmt.Errorf("check inventory tag format: %w", err)
	}

	if needsRebuild {
		if _, err := tx.ExecContext(ctx, `UPDATE items SET inventory_tag = NULL;`); err != nil {
			return fmt.Errorf("clear inventory tags: %w", err)
		}
		if _, err := tx.ExecContext(ctx, `SELECT setval('inventory_tag_seq', 1, false);`); err != nil {
			return fmt.Errorf("reset inventory tag sequence: %w", err)
		}
	}

	rows, err := tx.QueryContext(ctx, `
SELECT id
FROM items
WHERE inventory_tag IS NULL
ORDER BY created_at ASC, id ASC;
`)
	if err != nil {
		return fmt.Errorf("query missing inventory tags: %w", err)
	}
	defer rows.Close()

	ids := make([]string, 0)
	for rows.Next() {
		var idValue string
		if err := rows.Scan(&idValue); err != nil {
			return fmt.Errorf("scan missing inventory tag id: %w", err)
		}
		ids = append(ids, idValue)
	}

	if err := rows.Err(); err != nil {
		return fmt.Errorf("iterate missing inventory tags: %w", err)
	}
	rows.Close()

	for _, idValue := range ids {
		var next int64
		if err := tx.QueryRowContext(ctx, `SELECT nextval('inventory_tag_seq');`).Scan(&next); err != nil {
			return fmt.Errorf("next inventory tag: %w", err)
		}

		tag := id.EncodeCrockfordBase32(uint64(next), id.InventoryTagLength)
		if _, err := tx.ExecContext(ctx, `UPDATE items SET inventory_tag = $2 WHERE id = $1;`, idValue, tag); err != nil {
			return fmt.Errorf("update inventory tag: %w", err)
		}
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit inventory tag backfill: %w", err)
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
