# Pantry Helm Chart

This chart deploys:

- `pantry-backend` (Go API)
- `pantry-frontend` (Angular + Nginx)

It does **not** deploy PostgreSQL or MinIO. Configure external services via backend environment variables in `values.yaml`.

## Install

```bash
helm upgrade --install pantry ./misc/helm/pantry -n pantry --create-namespace
```

## Configure External Services

Set these values for your environment:

- `backend.env.DB_HOST`
- `backend.env.DB_PORT`
- `backend.env.DB_NAME`
- `backend.env.DB_USER`
- `backend.env.DB_SSLMODE`
- `backend.env.S3_ENDPOINT`
- `backend.env.S3_REGION`
- `backend.env.S3_BUCKET`
- `backend.env.S3_USE_PATH_STYLE`
- `backend.env.OIDC_ISSUER`

## Credentials With Sealed Secrets

Sensitive values are read from a Kubernetes `Secret`:

- `DB_PASSWORD`
- `S3_ACCESS_KEY_ID`
- `S3_SECRET_ACCESS_KEY`

Option 1: Use an existing Secret:

- set `backend.credentials.existingSecretName`
- optionally adjust `backend.credentials.keys.*`

Option 2: Let this chart create a `SealedSecret`:

- set `sealedSecrets.backendCredentials.enabled=true`
- set `sealedSecrets.backendCredentials.encryptedData` with sealed values for:
  - `DB_PASSWORD`
  - `S3_ACCESS_KEY_ID`
  - `S3_SECRET_ACCESS_KEY`

You can generate encrypted values with `kubeseal` and paste them into `values.yaml`.

Alternative non-sealed options:

- `backend.extraEnvFrom` with `secretRef`
- or `backend.extraEnv` entries using `valueFrom.secretKeyRef`

## Frontend Upstream

By default, frontend proxies API requests to the backend service in the same release:

- `BACKEND_UPSTREAM=<release>-pantry-backend:4000`

Override with:

- `frontend.backendUpstream`

## OIDC Configuration

Set frontend OIDC environment variables under `frontend.env`, for example:

- `frontend.env.OIDC_ENABLED`
- `frontend.env.OIDC_ISSUER`
- `frontend.env.OIDC_CLIENT_ID`
- `frontend.env.OIDC_REDIRECT_URI`
- `frontend.env.OIDC_POST_LOGOUT_REDIRECT_URI`
- `frontend.env.OIDC_SCOPE`

## Ingress

Enable and configure ingress with:

- `ingress.enabled=true`
- `ingress.className`
- `ingress.hosts`
- `ingress.tls`
