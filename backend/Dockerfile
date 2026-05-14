# syntax=docker/dockerfile:1.24

FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS builder
WORKDIR /src

ARG TARGETOS
ARG TARGETARCH

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH} go build -trimpath -ldflags="-s -w" -o /out/pantry-api ./cmd/api

FROM alpine:3.23
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY --from=builder /out/pantry-api /usr/local/bin/pantry-api

USER app
EXPOSE 4000
ENTRYPOINT ["/usr/local/bin/pantry-api"]
