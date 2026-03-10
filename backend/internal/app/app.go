package app

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/klausmeyer/pantry/backend/internal/config"
	"github.com/klausmeyer/pantry/backend/internal/http/handler"
	"github.com/klausmeyer/pantry/backend/internal/id"
	"github.com/klausmeyer/pantry/backend/internal/postgres"
	"github.com/klausmeyer/pantry/backend/internal/service"
	"github.com/klausmeyer/pantry/backend/internal/storage"
)

type App struct {
	cfg    config.Config
	router http.Handler
	db     *sql.DB
}

func New(cfg config.Config) (*App, error) {
	mux := http.NewServeMux()

	db, err := postgres.OpenDB(cfg.DB)
	if err != nil {
		return nil, fmt.Errorf("init postgres db: %w", err)
	}

	repo, err := postgres.NewItemRepository(db)
	if err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("init postgres item repository: %w", err)
	}

	ids := id.NewGenerator()
	itemsService := service.NewItemService(repo, ids)
	itemsHandler := handler.NewItemsHandler(itemsService)

	presigner, err := storage.NewS3Presigner(context.Background(), cfg.S3)
	if err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("init s3 presigner: %w", err)
	}
	uploadsHandler := handler.NewUploadsHandler(presigner, ids)

	if cfg.Seed.DevData {
		seedCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()

		if err := seedDevelopmentItems(seedCtx, itemsService, cfg.Seed.DevDataCount); err != nil {
			_ = db.Close()
			return nil, fmt.Errorf("seed development items: %w", err)
		}
		log.Printf("development seeding checked (count=%d)", cfg.Seed.DevDataCount)
	}

	mux.HandleFunc("GET /healthz", handler.Health())
	mux.HandleFunc("GET /api/items", itemsHandler.List)
	mux.HandleFunc("POST /api/items", itemsHandler.Create)
	mux.HandleFunc("PATCH /api/items/{id}", itemsHandler.Update)
	mux.HandleFunc("DELETE /api/items/{id}", itemsHandler.Delete)
	mux.HandleFunc("POST /api/uploads", uploadsHandler.Create)
	mux.HandleFunc("GET /api/uploads/preview", uploadsHandler.Preview)

	log.Printf("db configured for %s:%d/%s", cfg.DB.Host, cfg.DB.Port, cfg.DB.Name)
	log.Printf("s3 configured for %s bucket=%s", cfg.S3.Endpoint, cfg.S3.Bucket)

	return &App{cfg: cfg, router: withCORS(mux), db: db}, nil
}

func (a *App) Router() http.Handler {
	return a.router
}

func (a *App) Close() error {
	if a.db == nil {
		return nil
	}
	return a.db.Close()
}

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Accept, Content-Type")
		w.Header().Set("Vary", "Origin, Access-Control-Request-Method, Access-Control-Request-Headers")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)
	})
}
