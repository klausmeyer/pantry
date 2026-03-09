package postgres

import (
	"context"
	"database/sql"
	"fmt"
	"net/url"
	"strconv"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/klausmeyer/pantry/backend/internal/config"
)

func OpenDB(cfg config.DBConfig) (*sql.DB, error) {
	dsn := (&url.URL{
		Scheme: "postgres",
		User:   url.UserPassword(cfg.User, cfg.Password),
		Host:   cfg.Host + ":" + strconv.Itoa(cfg.Port),
		Path:   cfg.Name,
		RawQuery: url.Values{
			"sslmode": []string{cfg.SSLMode},
		}.Encode(),
	}).String()

	db, err := sql.Open("pgx", dsn)
	if err != nil {
		return nil, fmt.Errorf("open postgres connection: %w", err)
	}

	pingCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := db.PingContext(pingCtx); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("ping postgres: %w", err)
	}

	return db, nil
}
