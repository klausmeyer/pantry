package app

import (
	"log"
	"net/http"

	"github.com/klausmeyer/pantry/backend/internal/config"
	"github.com/klausmeyer/pantry/backend/internal/http/handler"
	"github.com/klausmeyer/pantry/backend/internal/id"
	"github.com/klausmeyer/pantry/backend/internal/memory"
	"github.com/klausmeyer/pantry/backend/internal/service"
)

type App struct {
	cfg    config.Config
	router http.Handler
}

func New(cfg config.Config) *App {
	mux := http.NewServeMux()

	repo := memory.NewItemRepository()
	ids := id.NewGenerator()
	itemsService := service.NewItemService(repo, ids)
	itemsHandler := handler.NewItemsHandler(itemsService)

	mux.HandleFunc("GET /healthz", handler.Health())
	mux.HandleFunc("GET /api/items", itemsHandler.List)
	mux.HandleFunc("POST /api/items", itemsHandler.Create)

	log.Printf("db configured for %s:%d/%s", cfg.DB.Host, cfg.DB.Port, cfg.DB.Name)
	log.Printf("s3 configured for %s bucket=%s", cfg.S3.Endpoint, cfg.S3.Bucket)

	return &App{cfg: cfg, router: mux}
}

func (a *App) Router() http.Handler {
	return a.router
}
