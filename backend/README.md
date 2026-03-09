# Pantry Backend

Initial Go backend scaffold for Pantry.

## What is included

- HTTP server with graceful shutdown
- Config loading via environment variables
- Starter endpoints:
  - `GET /healthz`
  - `GET /api/items`
  - `POST /api/items`
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
- `POST /api/items` returns:
  - `{ "data": { "type": "items", "id": "...", "attributes": { ... } } }`
- Validation and parsing failures return JSON:API error documents:
  - `{ "errors": [ { "status": "400", "title": "...", "detail": "..." } ] }`

## Next steps

- Add object storage adapter for item pictures in S3
- Add migrations under `migrations/`
