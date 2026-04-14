# syntax=docker/dockerfile:1.23

FROM node:24-alpine AS builder
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build && \
    if [ -d dist/pantry-frontend/browser ]; then \
      cp -R dist/pantry-frontend/browser /tmp/frontend-dist; \
    else \
      cp -R dist/pantry-frontend /tmp/frontend-dist; \
    fi

FROM nginx:1.29-alpine
ENV BACKEND_UPSTREAM=backend:4000
ENV NGINX_ENVSUBST_FILTER=BACKEND_UPSTREAM
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
COPY --from=builder /tmp/frontend-dist/ /usr/share/nginx/html/

COPY docker/40-envsubst-oidc-config.sh /docker-entrypoint.d/40-envsubst-oidc-config.sh

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
