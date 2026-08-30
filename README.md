# Pantry

Pantry helps you track household food supplies with a JSON:API backend and an Angular frontend.

## Project Layout

- `api/` - OpenAPI 3.1 specification
  See [`api/openapi.yaml`](api/openapi.yaml)
- `backend/` - Go API service, PostgreSQL repository, local infra via Docker Compose
  See [`backend/README.md`](backend/README.md)
- `frontend/` - Angular UI (Tailwind + DaisyUI)
  See [`frontend/README.md`](frontend/README.md)
- `mobile/` - Flutter mobile app
  See [`mobile/README.md`](mobile/README.md)
- `misc/` - helper scripts (for example CSV import tooling)

## Quick Start

1. Start backend dependencies and run the API
   Follow the steps in [`backend/README.md`](backend/README.md).
2. Start the frontend app
   Follow the steps in [`frontend/README.md`](frontend/README.md).
3. Review the contract and examples
   Use [`api/openapi.yaml`](api/openapi.yaml).

## Docker Deployment

Create local OIDC config from the example:

```bash
cp .env.local.example .env.local
```

Fill in the values for your external OIDC provider, then build and run the stack (frontend, backend, PostgreSQL, MinIO):

```bash
docker compose --env-file .env.local up --build -d
```

Endpoints:

- Frontend: `http://localhost:8080`
- Backend API: `http://localhost:4000`
- MinIO API: `http://localhost:9000`
- MinIO Console: `http://localhost:9001`

Stop everything:

```bash
docker compose down
```

The frontend container proxies `/api/*`, `/auth/authorize`, `/auth/exchange`, `/auth/refresh`, `/auth/logout`, and `/healthz` to the backend container.

## OIDC Authentication

The stack now uses OIDC for authentication.

- Backend requires a valid OIDC issuer, client ID, client secret, redirect URI, and validates bearer tokens for API routes.
- Frontend starts the authorization redirect through `/auth/authorize`; the backend exchanges authorization codes and refresh tokens with the client secret.
- `docker-compose.yml` reads external OIDC settings from `.env.local` when run with `--env-file .env.local`.

Do not expose `OIDC_CLIENT_SECRET` through the frontend config.

## Development Notes

- API media type: `application/vnd.api+json`
- Default local API URL: `http://localhost:4000`
- Item attributes include `inventory_tag` (auto-generated 4-character tag, searchable via `q`, with optional `#` prefix).
- This repository follows the goals and scope described in [`INSTRUCTIONS.md`](INSTRUCTIONS.md)
