package handler

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/coreos/go-oidc/v3/oidc"
	"github.com/klausmeyer/pantry/backend/internal/config"
	"github.com/klausmeyer/pantry/backend/pkg/httputil"
	"golang.org/x/oauth2"
)

type AuthHandler struct {
	oauthConfig           *oauth2.Config
	verifier              *oidc.IDTokenVerifier
	logoutURL             string
	postLogoutRedirectURI string
}

func NewAuthHandler(ctx context.Context, cfg config.OIDCConfig) (*AuthHandler, error) {
	provider, err := oidc.NewProvider(ctx, strings.TrimSpace(cfg.Issuer))
	if err != nil {
		return nil, err
	}

	var providerMetadata struct {
		EndSessionEndpoint string `json:"end_session_endpoint"`
	}
	if err := provider.Claims(&providerMetadata); err != nil {
		return nil, err
	}

	oauthConfig := &oauth2.Config{
		ClientID:     cfg.ClientID,
		ClientSecret: cfg.ClientSecret,
		Endpoint:     provider.Endpoint(),
		RedirectURL:  cfg.RedirectURI,
		Scopes:       strings.Fields(cfg.Scope),
	}

	verifier := provider.Verifier(&oidc.Config{
		ClientID: cfg.ClientID,
	})

	return &AuthHandler{
		oauthConfig:           oauthConfig,
		verifier:              verifier,
		logoutURL:             providerMetadata.EndSessionEndpoint,
		postLogoutRedirectURI: cfg.PostLogoutRedirectURI,
	}, nil
}

func (h *AuthHandler) Authorize(w http.ResponseWriter, r *http.Request) {
	state := strings.TrimSpace(r.URL.Query().Get("state"))
	nonce := strings.TrimSpace(r.URL.Query().Get("nonce"))
	if state == "" || nonce == "" {
		httputil.WriteJSONAPIError(w, http.StatusBadRequest, "bad_request", "state and nonce are required")
		return
	}

	authURL := h.oauthConfig.AuthCodeURL(
		state,
		oauth2.AccessTypeOffline,
		oauth2.SetAuthURLParam("nonce", nonce),
	)
	httputil.WriteJSONAPI(w, http.StatusOK, map[string]any{
		"data": map[string]any{
			"type": "auth-url",
			"attributes": map[string]string{
				"url": authURL,
			},
		},
	})
}

func (h *AuthHandler) Exchange(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Code  string `json:"code"`
		Nonce string `json:"nonce"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteJSONAPIError(w, http.StatusBadRequest, "bad_request", "invalid JSON body")
		return
	}
	req.Code = strings.TrimSpace(req.Code)
	req.Nonce = strings.TrimSpace(req.Nonce)
	if req.Code == "" || req.Nonce == "" {
		httputil.WriteJSONAPIError(w, http.StatusBadRequest, "bad_request", "code and nonce are required")
		return
	}

	token, err := h.oauthConfig.Exchange(r.Context(), req.Code)
	if err != nil {
		httputil.WriteJSONAPIError(w, http.StatusUnauthorized, "unauthorized", "authorization code exchange failed")
		return
	}
	h.writeVerifiedToken(w, r.Context(), token, req.Nonce)
}

func (h *AuthHandler) Refresh(w http.ResponseWriter, r *http.Request) {
	var req struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteJSONAPIError(w, http.StatusBadRequest, "bad_request", "invalid JSON body")
		return
	}
	req.RefreshToken = strings.TrimSpace(req.RefreshToken)
	if req.RefreshToken == "" {
		httputil.WriteJSONAPIError(w, http.StatusBadRequest, "bad_request", "refresh_token is required")
		return
	}

	token, err := h.oauthConfig.TokenSource(r.Context(), &oauth2.Token{RefreshToken: req.RefreshToken}).Token()
	if err != nil {
		httputil.WriteJSONAPIError(w, http.StatusUnauthorized, "unauthorized", "refresh token exchange failed")
		return
	}
	h.writeVerifiedToken(w, r.Context(), token, "")
}

func (h *AuthHandler) Logout(w http.ResponseWriter, r *http.Request) {
	logoutURL := strings.TrimSpace(h.logoutURL)
	if logoutURL == "" {
		logoutURL = h.postLogoutRedirectURI
	}

	parsed, err := url.Parse(logoutURL)
	if err != nil {
		httputil.WriteJSONAPIError(w, http.StatusInternalServerError, "server_error", "invalid logout endpoint")
		return
	}

	query := parsed.Query()
	if h.postLogoutRedirectURI != "" {
		query.Set("post_logout_redirect_uri", h.postLogoutRedirectURI)
	}
	if h.oauthConfig.ClientID != "" {
		query.Set("client_id", h.oauthConfig.ClientID)
	}
	if idTokenHint := strings.TrimSpace(r.URL.Query().Get("id_token_hint")); idTokenHint != "" {
		query.Set("id_token_hint", idTokenHint)
	}
	parsed.RawQuery = query.Encode()

	httputil.WriteJSONAPI(w, http.StatusOK, map[string]any{
		"data": map[string]any{
			"type": "logout-url",
			"attributes": map[string]string{
				"url": parsed.String(),
			},
		},
	})
}

func (h *AuthHandler) writeVerifiedToken(w http.ResponseWriter, ctx context.Context, token *oauth2.Token, nonce string) {
	var profile map[string]any
	idToken, err := h.verifyIDToken(ctx, token, nonce)
	if err != nil {
		if nonce != "" || !errors.Is(err, errMissingIDToken) {
			httputil.WriteJSONAPIError(w, http.StatusUnauthorized, "unauthorized", err.Error())
			return
		}
	} else if err := idToken.Claims(&profile); err != nil {
		httputil.WriteJSONAPIError(w, http.StatusUnauthorized, "unauthorized", "invalid id token claims")
		return
	}

	httputil.WriteJSONAPI(w, http.StatusOK, map[string]any{
		"data": map[string]any{
			"type": "auth-token",
			"attributes": map[string]any{
				"access_token":  token.AccessToken,
				"refresh_token": token.RefreshToken,
				"id_token":      token.Extra("id_token"),
				"token_type":    token.TokenType,
				"expires_at":    token.Expiry.Format(time.RFC3339),
				"profile":       profile,
			},
		},
	})
}

func (h *AuthHandler) verifyIDToken(ctx context.Context, token *oauth2.Token, nonce string) (*oidc.IDToken, error) {
	rawIDToken, ok := token.Extra("id_token").(string)
	if !ok || rawIDToken == "" {
		return nil, errMissingIDToken
	}

	idToken, err := h.verifier.Verify(ctx, rawIDToken)
	if err != nil {
		return nil, errors.New("invalid id token")
	}

	if nonce != "" {
		var claims struct {
			Nonce string `json:"nonce"`
		}
		if err := idToken.Claims(&claims); err != nil {
			return nil, errors.New("invalid id token claims")
		}
		if claims.Nonce != nonce {
			return nil, errors.New("invalid nonce")
		}
	}

	return idToken, nil
}

var errMissingIDToken = errors.New("missing id token")
