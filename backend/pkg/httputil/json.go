package httputil

import (
	"encoding/json"
	"net/http"
	"strconv"
)

func WriteJSONAPI(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/vnd.api+json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func WriteJSONAPIError(w http.ResponseWriter, status int, title, detail string) {
	WriteJSONAPI(w, status, map[string]any{
		"errors": []map[string]string{
			{
				"status": strconv.Itoa(status),
				"title":  title,
				"detail": detail,
			},
		},
	})
}
