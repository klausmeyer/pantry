package handler

import (
	"context"
	"encoding/json"
	"net/http"
	"path/filepath"
	"strings"
	"time"

	"github.com/klausmeyer/pantry/backend/internal/id"
	"github.com/klausmeyer/pantry/backend/pkg/httputil"
)

type UploadsHandler struct {
	presigner UploadPresigner
	ids       *id.Generator
}

type UploadPresigner interface {
	PresignPut(ctx context.Context, key, contentType string, expires time.Duration) (string, map[string]string, error)
	PresignGet(ctx context.Context, key string, expires time.Duration) (string, error)
	Copy(ctx context.Context, sourceKey, destKey string) error
}

func NewUploadsHandler(presigner UploadPresigner, ids *id.Generator) *UploadsHandler {
	return &UploadsHandler{presigner: presigner, ids: ids}
}

type uploadRequest struct {
	Filename    string `json:"filename"`
	ContentType string `json:"content_type"`
}

type uploadResponse struct {
	Data struct {
		Type       string `json:"type"`
		Attributes struct {
			PictureKey string            `json:"picture_key"`
			UploadURL  string            `json:"upload_url"`
			Headers    map[string]string `json:"headers"`
		} `json:"attributes"`
	} `json:"data"`
}

type uploadPreviewResponse struct {
	Data struct {
		Type       string `json:"type"`
		Attributes struct {
			PictureKey string `json:"picture_key"`
			PreviewURL string `json:"preview_url"`
		} `json:"attributes"`
	} `json:"data"`
}

type cloneRequest struct {
	PictureKey string `json:"picture_key"`
}

type cloneResponse struct {
	Data struct {
		Type       string `json:"type"`
		Attributes struct {
			PictureKey string `json:"picture_key"`
		} `json:"attributes"`
	} `json:"data"`
}

var allowedImageTypes = map[string]string{
	"image/jpeg": ".jpg",
	"image/jpg":  ".jpg",
	"image/png":  ".png",
	"image/webp": ".webp",
	"image/gif":  ".gif",
}

var allowedImageExtensions = map[string]map[string]bool{
	"image/jpeg": {".jpg": true, ".jpeg": true},
	"image/jpg":  {".jpg": true, ".jpeg": true},
	"image/png":  {".png": true},
	"image/webp": {".webp": true},
	"image/gif":  {".gif": true},
}

func (h *UploadsHandler) Create(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	if !isJSONRequest(r.Header.Get("Content-Type")) {
		httputil.WriteJSONAPIError(w, http.StatusUnsupportedMediaType, "unsupported media type", "content-type must be application/json")
		return
	}

	var req uploadRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteJSONAPIError(w, http.StatusBadRequest, "invalid request", "request body must be valid JSON")
		return
	}

	contentType := strings.TrimSpace(strings.ToLower(req.ContentType))
	if contentType == "" {
		httputil.WriteJSONAPIError(w, http.StatusBadRequest, "invalid content_type", "content_type is required")
		return
	}

	ext, ok := allowedImageTypes[contentType]
	if !ok {
		httputil.WriteJSONAPIError(w, http.StatusBadRequest, "invalid content_type", "only jpeg, png, webp, or gif images are supported")
		return
	}

	filenameExt := strings.ToLower(filepath.Ext(req.Filename))
	if filenameExt != "" && allowedImageExtensions[contentType][filenameExt] {
		ext = filenameExt
	}

	key := "items/" + h.ids.New() + ext
	uploadURL, headers, err := h.presigner.PresignPut(r.Context(), key, contentType, 10*time.Minute)
	if err != nil {
		httputil.WriteJSONAPIError(w, http.StatusInternalServerError, "upload error", "could not create upload URL")
		return
	}

	var resp uploadResponse
	resp.Data.Type = "uploads"
	resp.Data.Attributes.PictureKey = key
	resp.Data.Attributes.UploadURL = uploadURL
	resp.Data.Attributes.Headers = headers

	httputil.WriteJSONAPI(w, http.StatusCreated, resp)
}

func (h *UploadsHandler) Preview(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	pictureKey := strings.TrimSpace(r.URL.Query().Get("picture_key"))
	if pictureKey == "" {
		httputil.WriteJSONAPIError(w, http.StatusBadRequest, "invalid picture_key", "picture_key query parameter is required")
		return
	}

	previewURL, err := h.presigner.PresignGet(r.Context(), pictureKey, 10*time.Minute)
	if err != nil {
		httputil.WriteJSONAPIError(w, http.StatusInternalServerError, "preview error", "could not create preview URL")
		return
	}

	var resp uploadPreviewResponse
	resp.Data.Type = "uploads"
	resp.Data.Attributes.PictureKey = pictureKey
	resp.Data.Attributes.PreviewURL = previewURL

	httputil.WriteJSONAPI(w, http.StatusOK, resp)
}

func (h *UploadsHandler) Clone(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	if !isJSONRequest(r.Header.Get("Content-Type")) {
		httputil.WriteJSONAPIError(w, http.StatusUnsupportedMediaType, "unsupported media type", "content-type must be application/json")
		return
	}

	var req cloneRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteJSONAPIError(w, http.StatusBadRequest, "invalid request", "request body must be valid JSON")
		return
	}

	sourceKey := strings.TrimSpace(req.PictureKey)
	if sourceKey == "" {
		httputil.WriteJSONAPIError(w, http.StatusBadRequest, "invalid picture_key", "picture_key is required")
		return
	}

	ext := strings.ToLower(filepath.Ext(sourceKey))
	destKey := "items/" + h.ids.New() + ext
	if err := h.presigner.Copy(r.Context(), sourceKey, destKey); err != nil {
		httputil.WriteJSONAPIError(w, http.StatusInternalServerError, "clone error", "could not clone image")
		return
	}

	var resp cloneResponse
	resp.Data.Type = "uploads"
	resp.Data.Attributes.PictureKey = destKey

	httputil.WriteJSONAPI(w, http.StatusCreated, resp)
}

func isJSONRequest(contentType string) bool {
	contentType = strings.ToLower(contentType)
	if contentType == "" {
		return false
	}
	if strings.HasPrefix(contentType, "application/json") {
		return true
	}
	if strings.HasPrefix(contentType, "application/vnd.api+json") {
		return true
	}
	return false
}
