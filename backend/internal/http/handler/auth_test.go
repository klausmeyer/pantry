package handler

import (
	"encoding/json"
	"net/http/httptest"
	"net/url"
	"testing"

	"golang.org/x/oauth2"
)

func TestAuthHandlerLogout_BuildsEndSessionURL(t *testing.T) {
	h := &AuthHandler{
		oauthConfig:           &oauth2.Config{ClientID: "pantry"},
		logoutURL:             "https://idp.example.com/realms/pantry/protocol/openid-connect/logout",
		postLogoutRedirectURI: "http://localhost:4200/",
	}
	req := httptest.NewRequest("GET", "/auth/logout?id_token_hint=id-token-123", nil)
	rec := httptest.NewRecorder()

	h.Logout(rec, req)

	if rec.Code != 200 {
		t.Fatalf("expected 200, got %d", rec.Code)
	}

	var body struct {
		Data struct {
			Attributes struct {
				URL string `json:"url"`
			} `json:"attributes"`
		} `json:"data"`
	}
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	logoutURL, err := url.Parse(body.Data.Attributes.URL)
	if err != nil {
		t.Fatalf("parse logout URL: %v", err)
	}
	query := logoutURL.Query()
	if query.Get("client_id") != "pantry" {
		t.Fatalf("expected client_id pantry, got %q", query.Get("client_id"))
	}
	if query.Get("id_token_hint") != "id-token-123" {
		t.Fatalf("expected id token hint, got %q", query.Get("id_token_hint"))
	}
	if query.Get("post_logout_redirect_uri") != "http://localhost:4200/" {
		t.Fatalf("expected post logout redirect, got %q", query.Get("post_logout_redirect_uri"))
	}
}
