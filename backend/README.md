# Pantry Backend

Initial Go backend scaffold for Pantry.

## What is included

- HTTP server with graceful shutdown
- Config loading via environment variables
- Starter endpoints:
  - `GET /healthz`
  - `GET /api/items`
  - `POST /api/items`
  - `PATCH /api/items/{id}`
  - `DELETE /api/items/{id}` (soft delete)
- PostgreSQL-backed item repository
- Local dependencies via Docker Compose (PostgreSQL + MinIO)

## Quick start

1. Start local dependencies:

```bash
cd backend
make deps-up
```

2. Run backend:

```bash
cd backend
make run
```

3. Check health endpoint:

```bash
curl http://localhost:4000/healthz
```

## OIDC Authentication

The backend now validates bearer tokens using an OIDC issuer.

- Configure the issuer with `OIDC_ISSUER`.
- All API routes require a bearer token; `/healthz` and `OPTIONS` remain public.
- `docker-compose.yml` provisions a local Keycloak instance and sets `OIDC_ISSUER` to `http://localhost:8081/realms/test`.

## Development seeds

You can seed dummy data on startup. Seeding runs only if the `items` table is empty.

```bash
SEED_DEV_DATA=true SEED_DEV_DATA_COUNT=100 make run
```

## JSON:API example create item request

```bash
curl -X POST http://localhost:4000/api/items \
  -H 'content-type: application/vnd.api+json' \
  -d '{
    "data": {
      "type": "items",
      "attributes": {
        "name": "Rice",
        "best_before": "2026-12-31",
        "content_amount": 500,
        "content_unit": "grams",
        "packaging": "bag",
        "picture_key": "items/rice.png",
        "comment": "Basmatireis"
      }
    }
  }'
```

## JSON:API response shape

- `GET /api/items` returns:
  - `{ "data": [ { "type": "items", "id": "...", "attributes": { ... } } ] }`
  - Supports JSON:API sorting with query param:
    - `sort`: `id | name | best_before | created_at | updated_at`
    - prefix with `-` for descending (example: `sort=best_before,-name`)
    - default is `sort=id` (ascending)
  - Supports search with `q` against `name`, `comment`, and `inventory_tag`
    - use `#` prefix to search tags only (example: `q=#7K2R`)
- `POST /api/items` returns:
  - `{ "data": { "type": "items", "id": "...", "attributes": { ... } } }`
- `PATCH /api/items/{id}` updates an item:
  - request body uses JSON:API `data` object with matching `type` and `id`
  - returns updated resource in `{ "data": { ... } }`
- `DELETE /api/items/{id}` performs soft deletion:
  - returns `204 No Content`
  - deleted items are excluded from `GET /api/items`
- `packaging` is required and must be one of:
  - `bottle | can | box | bag | jar | package | other`
- Item attributes include `inventory_tag`, a 4-character auto-generated lookup tag.
- Validation and parsing failures return JSON:API error documents:
  - `{ "errors": [ { "status": "400", "title": "...", "detail": "..." } ] }`

## Next steps

- Add object storage adapter for item pictures in S3
- Add migrations under `migrations/`
