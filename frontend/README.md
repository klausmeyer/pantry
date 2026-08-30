# Pantry Frontend

Angular frontend for Pantry.

## Start

```bash
cd frontend
npm install
npm start
```

The app expects the backend API on `http://localhost:4000`.

## OIDC Configuration

The frontend reads public OIDC settings from `oidc-config.js`, which is loaded by `src/index.html`.

- Docker builds generate `oidc-config.js` from `OIDC_*` environment variables.
- For Docker Compose, copy `.env.local.example` to `.env.local` and run with `docker compose --env-file .env.local up --build -d`.
- For local dev with `npm start`, create `frontend/src/oidc-config.js` and set `window.__PANTRY_OIDC__` overrides (you can copy `frontend/src/oidc-config.js.tpl` or `oidc-config.js.template` and fill in your values).
- Set `OIDC_ENABLED=false` to disable authentication in the UI.
- The browser never receives `OIDC_CLIENT_SECRET`; authorization-code, refresh-token, and logout URL handling go through the backend `/auth/authorize`, `/auth/exchange`, `/auth/refresh`, and `/auth/logout` endpoints.
