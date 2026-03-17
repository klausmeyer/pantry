# Pantry

Pantry helps you track household food supplies with a JSON:API backend and an Angular frontend.

## Project Layout

- `api/` - OpenAPI 3.1 specification  
  See [`api/openapi.yaml`](api/openapi.yaml)
- `backend/` - Go API service, PostgreSQL repository, local infra via Docker Compose  
  See [`backend/README.md`](backend/README.md)
- `frontend/` - Angular UI (Tailwind + DaisyUI)  
  See [`frontend/README.md`](frontend/README.md)
- `misc/helm/pantry/` - Helm chart for Kubernetes deployments  
  See [`misc/helm/pantry/README.md`](misc/helm/pantry/README.md)
- `misc/` - helper scripts (for example CSV import tooling)

## Quick Start

1. Start backend dependencies and run the API  
   Follow the steps in [`backend/README.md`](backend/README.md).
2. Start the frontend app  
   Follow the steps in [`frontend/README.md`](frontend/README.md).
3. Review the contract and examples  
   Use [`api/openapi.yaml`](api/openapi.yaml).

## Docker Deployment

Build and run the full stack (frontend, backend, PostgreSQL, MinIO):

```bash
docker compose up --build -d
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

The frontend container proxies `/api/*` and `/healthz` to the backend container.

## OIDC Authentication

The stack now uses OIDC for authentication.

- Backend requires a valid OIDC issuer and validates bearer tokens for API routes.
- Frontend reads OIDC settings from `oidc-config.js`, which is generated from `OIDC_*` environment variables in Docker.
- `docker-compose.yml` includes a local Keycloak instance and wires both services to the `http://localhost:8081/realms/test` issuer.

If you use a different identity provider, update `OIDC_ISSUER` on the backend and the `OIDC_*` variables for the frontend.

## Kubernetes Deployment

For Kubernetes installs, use the Helm chart in [`misc/helm/pantry`](misc/helm/pantry).
Chart usage and configuration are documented in [`misc/helm/pantry/README.md`](misc/helm/pantry/README.md).

## Development Notes

- API media type: `application/vnd.api+json`
- Default local API URL: `http://localhost:4000`
- This repository follows the goals and scope described in [`INSTRUCTIONS.md`](INSTRUCTIONS.md)
