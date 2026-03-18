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

The frontend reads OIDC settings from `oidc-config.js`, which is loaded by `src/index.html`.

- Docker builds generate `oidc-config.js` from `OIDC_*` environment variables.
- For local dev with `npm start`, create `frontend/src/oidc-config.js` and set `window.__PANTRY_OIDC__` overrides (you can copy `frontend/src/oidc-config.js.tpl` or `oidc-config.js.template` and fill in your values).
- Set `OIDC_ENABLED=false` to disable authentication in the UI.

Silent renew (hidden iframe) is enabled by default and uses `/auth/silent` for the callback. You can override:
- `OIDC_SILENT_REDIRECT_URI` (default `${origin}/auth/silent`)
- `OIDC_SILENT_RENEW_ENABLED` (`true` or `false`)
