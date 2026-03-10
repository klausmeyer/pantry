CREATE EXTENSION IF NOT EXISTS unaccent;

CREATE OR REPLACE FUNCTION items_search_text() RETURNS trigger AS $$
BEGIN
  NEW.search_text := unaccent(lower(coalesce(NEW.name, '') || ' ' || coalesce(NEW.comment, '')));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS items (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  best_before DATE NOT NULL,
  content_amount DOUBLE PRECISION NOT NULL,
  content_unit TEXT NOT NULL,
  packaging TEXT NOT NULL,
  picture_key TEXT,
  comment TEXT,
  search_text TEXT,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  deleted_at TIMESTAMPTZ
);

CREATE TRIGGER items_search_text_trigger
BEFORE INSERT OR UPDATE OF name, comment ON items
FOR EACH ROW
EXECUTE FUNCTION items_search_text();
