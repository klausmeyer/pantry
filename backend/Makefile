.PHONY: run test fmt deps-up deps-down

run:
	go run ./cmd/api

test:
	go test ./...

fmt:
	gofmt -w ./cmd ./internal ./pkg

deps-up:
	docker compose up -d

deps-down:
	docker compose down
