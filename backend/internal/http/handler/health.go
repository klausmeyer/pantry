package handler

import (
	"net/http"

	"github.com/klausmeyer/pantry/backend/pkg/httputil"
)

func Health() http.HandlerFunc {
	return func(w http.ResponseWriter, _ *http.Request) {
		httputil.WriteJSONAPI(w, http.StatusOK, map[string]any{
			"meta": map[string]string{"status": "ok"},
		})
	}
}
