package config

import (
	"errors"
	"fmt"
	"os"
	"strconv"
)

type Config struct {
	HTTPAddr string
	DB       DBConfig
	S3       S3Config
	Seed     SeedConfig
	OIDC     OIDCConfig
}

type DBConfig struct {
	Host     string
	Port     int
	Name     string
	User     string
	Password string
	SSLMode  string
}

type S3Config struct {
	Endpoint        string
	Region          string
	Bucket          string
	AccessKeyID     string
	SecretAccessKey string
	UsePathStyle    bool
}

type SeedConfig struct {
	DevData      bool
	DevDataCount int
}

type OIDCConfig struct {
	Issuer   string
	ClientID string
	Audience string
}

func Load() (Config, error) {
	cfg := Config{
		HTTPAddr: getenv("HTTP_ADDR", ":4000"),
		DB: DBConfig{
			Host:     getenv("DB_HOST", "localhost"),
			Port:     getenvInt("DB_PORT", 5432),
			Name:     getenv("DB_NAME", "pantry"),
			User:     getenv("DB_USER", "pantry"),
			Password: getenv("DB_PASSWORD", "pantry"),
			SSLMode:  getenv("DB_SSLMODE", "disable"),
		},
		S3: S3Config{
			Endpoint:        getenv("S3_ENDPOINT", "http://localhost:9000"),
			Region:          getenv("S3_REGION", "eu-central-1"),
			Bucket:          getenv("S3_BUCKET", "pantry"),
			AccessKeyID:     getenv("S3_ACCESS_KEY_ID", "minioadmin"),
			SecretAccessKey: getenv("S3_SECRET_ACCESS_KEY", "minioadmin"),
			UsePathStyle:    getenvBool("S3_USE_PATH_STYLE", true),
		},
		Seed: SeedConfig{
			DevData:      getenvBool("SEED_DEV_DATA", false),
			DevDataCount: getenvInt("SEED_DEV_DATA_COUNT", 100),
		},
		OIDC: OIDCConfig{
			Issuer: getenv("OIDC_ISSUER", "https://example.com"),
		},
	}

	if cfg.HTTPAddr == "" {
		return Config{}, errors.New("HTTP_ADDR must not be empty")
	}
	if cfg.DB.Port <= 0 {
		return Config{}, fmt.Errorf("DB_PORT must be positive, got %d", cfg.DB.Port)
	}
	if cfg.Seed.DevDataCount <= 0 {
		return Config{}, fmt.Errorf("SEED_DEV_DATA_COUNT must be positive, got %d", cfg.Seed.DevDataCount)
	}
	if cfg.OIDC.Issuer == "" {
		return Config{}, errors.New("OIDC_ISSUER must not be empty")
	}

	return cfg, nil
}

func getenv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func getenvInt(key string, fallback int) int {
	raw := os.Getenv(key)
	if raw == "" {
		return fallback
	}
	value, err := strconv.Atoi(raw)
	if err != nil {
		return fallback
	}
	return value
}

func getenvBool(key string, fallback bool) bool {
	raw := os.Getenv(key)
	if raw == "" {
		return fallback
	}
	value, err := strconv.ParseBool(raw)
	if err != nil {
		return fallback
	}
	return value
}
