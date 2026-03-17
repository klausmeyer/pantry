package middleware

import (
	"context"
	"errors"
	"net/http"
	"strings"

	"github.com/coreos/go-oidc/v3/oidc"
	"github.com/klausmeyer/pantry/backend/internal/config"
	"github.com/klausmeyer/pantry/backend/pkg/httputil"
)

type OIDCVerifier struct {
	verifier *oidc.IDTokenVerifier
}

func NewOIDCVerifier(ctx context.Context, cfg config.OIDCConfig) (*OIDCVerifier, error) {
	issuer := strings.TrimSpace(cfg.Issuer)
	if issuer == "" {
		return nil, errors.New("oidc issuer is required")
	}

	provider, err := oidc.NewProvider(ctx, issuer)
	if err != nil {
		return nil, err
	}

	verifier := provider.Verifier(&oidc.Config{
		SkipClientIDCheck: true,
		SkipIssuerCheck:   true,
	})
	return &OIDCVerifier{verifier: verifier}, nil
}

func RequireAuth(verifier *OIDCVerifier, next http.Handler) http.Handler {
	if verifier == nil {
		return next
	}

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions || r.URL.Path == "/healthz" {
			next.ServeHTTP(w, r)
			return
		}

		authHeader := strings.TrimSpace(r.Header.Get("Authorization"))
		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "bearer") {
			httputil.WriteJSONAPIError(w, http.StatusUnauthorized, "unauthorized", "missing bearer token")
			return
		}

		token := strings.TrimSpace(parts[1])
		if token == "" {
			httputil.WriteJSONAPIError(w, http.StatusUnauthorized, "unauthorized", "missing bearer token")
			return
		}

		if _, err := verifier.verifier.Verify(r.Context(), token); err != nil {
			httputil.WriteJSONAPIError(w, http.StatusUnauthorized, "unauthorized", "invalid token")
			return
		}

		next.ServeHTTP(w, r)
	})
}
