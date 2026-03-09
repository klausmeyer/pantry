package handler

import (
	"net/http"

	"github.com/klausmeyer/pantry/backend/pkg/httputil"
)

func Health() http.HandlerFunc {
	return func(w http.ResponseWriter, _ *http.Request) {
		httputil.WriteJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	}
}
