# syntax=docker/dockerfile:1.7

FROM node:22-alpine AS builder
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

FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /tmp/frontend-dist/ /usr/share/nginx/html/

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

