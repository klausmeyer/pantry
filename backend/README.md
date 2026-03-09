# Pantry Backend

Initial Go backend scaffold for Pantry.

## What is included

- HTTP server with graceful shutdown
- Config loading via environment variables
- Starter endpoints:
  - `GET /healthz`
  - `GET /api/items`
  - `POST /api/items`
- In-memory item repository (temporary while Postgres integration is added)
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
curl http://localhost:8080/healthz
```

## Example create item request

```bash
curl -X POST http://localhost:8080/api/items \
  -H 'content-type: application/json' \
  -d '{
    "name": "Rice",
    "best_before": "2026-12-31",
    "content_amount": 500,
    "content_unit": "grams",
    "picture_key": "items/rice.png",
    "comment": "Basmatireis"
  }'
```

## Next steps

- Replace in-memory repository with PostgreSQL-backed repository
- Add object storage adapter for item pictures in S3
- Align responses with the JSON-API format from the API spec
- Add migrations under `migrations/`
