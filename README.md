# Pantry

Pantry helps you track household food supplies with a JSON:API backend and an Angular frontend.

## Project Layout

- `api/` - OpenAPI 3.1 specification  
  See [`api/openapi.yaml`](api/openapi.yaml)
- `backend/` - Go API service, PostgreSQL repository, local infra via Docker Compose  
  See [`backend/README.md`](backend/README.md)
- `frontend/` - Angular UI (Tailwind + DaisyUI)  
  See [`frontend/README.md`](frontend/README.md)
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

## Development Notes

- API media type: `application/vnd.api+json`
- Default local API URL: `http://localhost:4000`
- This repository follows the goals and scope described in [`INSTRUCTIONS.md`](INSTRUCTIONS.md)
