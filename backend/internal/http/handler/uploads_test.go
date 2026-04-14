package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/klausmeyer/pantry/backend/internal/id"
)

type fakePresigner struct {
	putKey         string
	putContentType string
	putExpires     time.Duration
	putURL         string
	putHeaders     map[string]string
	putErr         error

	getKey     string
	getExpires time.Duration
	getURL     string
	getErr     error

	copySource string
	copyDest   string
	copyErr    error
}

func (f *fakePresigner) PresignPut(ctx context.Context, key, contentType string, expires time.Duration) (string, map[string]string, error) {
	f.putKey = key
	f.putContentType = contentType
	f.putExpires = expires
	if f.putErr != nil {
		return "", nil, f.putErr
	}
	return f.putURL, f.putHeaders, nil
}

func (f *fakePresigner) PresignGet(ctx context.Context, key string, expires time.Duration) (string, error) {
	f.getKey = key
	f.getExpires = expires
	if f.getErr != nil {
		return "", f.getErr
	}
	return f.getURL, nil
}

func (f *fakePresigner) Copy(ctx context.Context, sourceKey, destKey string) error {
	f.copySource = sourceKey
	f.copyDest = destKey
	return f.copyErr
}

func TestUploadsCreate_MethodNotAllowed(t *testing.T) {
	h := NewUploadsHandler(&fakePresigner{}, id.NewGenerator())
	req := httptest.NewRequest(http.MethodGet, "/uploads", nil)
	res := httptest.NewRecorder()

	h.Create(res, req)

	if res.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected status 405, got %d", res.Code)
	}
}

func TestUploadsCreate_InvalidContentType(t *testing.T) {
	h := NewUploadsHandler(&fakePresigner{}, id.NewGenerator())
	body := bytes.NewBufferString(`{"filename":"a.png","content_type":"image/png"}`)
	req := httptest.NewRequest(http.MethodPost, "/uploads", body)
	req.Header.Set("Content-Type", "text/plain")
	res := httptest.NewRecorder()

	h.Create(res, req)

	if res.Code != http.StatusUnsupportedMediaType {
		t.Fatalf("expected status 415, got %d", res.Code)
	}
}

func TestUploadsCreate_InvalidJSON(t *testing.T) {
	h := NewUploadsHandler(&fakePresigner{}, id.NewGenerator())
	body := bytes.NewBufferString(`{"filename":`) // invalid
	req := httptest.NewRequest(http.MethodPost, "/uploads", body)
	req.Header.Set("Content-Type", "application/json")
	res := httptest.NewRecorder()

	h.Create(res, req)

	if res.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", res.Code)
	}
}

func TestUploadsCreate_MissingContentType(t *testing.T) {
	h := NewUploadsHandler(&fakePresigner{}, id.NewGenerator())
	body := bytes.NewBufferString(`{"filename":"a.png"}`)
	req := httptest.NewRequest(http.MethodPost, "/uploads", body)
	req.Header.Set("Content-Type", "application/json")
	res := httptest.NewRecorder()

	h.Create(res, req)

	if res.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", res.Code)
	}
}

func TestUploadsCreate_UnsupportedContentType(t *testing.T) {
	h := NewUploadsHandler(&fakePresigner{}, id.NewGenerator())
	body := bytes.NewBufferString(`{"filename":"a.bmp","content_type":"image/bmp"}`)
	req := httptest.NewRequest(http.MethodPost, "/uploads", body)
	req.Header.Set("Content-Type", "application/json")
	res := httptest.NewRecorder()

	h.Create(res, req)

	if res.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", res.Code)
	}
}

func TestUploadsCreate_PresignError(t *testing.T) {
	fake := &fakePresigner{putErr: errors.New("boom")}
	h := NewUploadsHandler(fake, id.NewGenerator())
	body := bytes.NewBufferString(`{"filename":"a.png","content_type":"image/png"}`)
	req := httptest.NewRequest(http.MethodPost, "/uploads", body)
	req.Header.Set("Content-Type", "application/json")
	res := httptest.NewRecorder()

	h.Create(res, req)

	if res.Code != http.StatusInternalServerError {
		t.Fatalf("expected status 500, got %d", res.Code)
	}
}

func TestUploadsCreate_Success(t *testing.T) {
	fake := &fakePresigner{putURL: "https://upload", putHeaders: map[string]string{"Content-Type": "image/jpeg"}}
	h := NewUploadsHandler(fake, id.NewGenerator())
	body := bytes.NewBufferString(`{"filename":"photo.jpeg","content_type":"image/jpeg"}`)
	req := httptest.NewRequest(http.MethodPost, "/uploads", body)
	req.Header.Set("Content-Type", "application/json; charset=utf-8")
	res := httptest.NewRecorder()

	h.Create(res, req)

	if res.Code != http.StatusCreated {
		t.Fatalf("expected status 201, got %d", res.Code)
	}

	var payload uploadResponse
	if err := json.NewDecoder(res.Body).Decode(&payload); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	pictureKey := payload.Data.Attributes.PictureKey
	if !strings.HasPrefix(pictureKey, "items/") {
		t.Fatalf("expected picture key to start with items/, got %q", pictureKey)
	}
	if !strings.HasSuffix(pictureKey, ".jpeg") {
		t.Fatalf("expected picture key to end with .jpeg, got %q", pictureKey)
	}
	if fake.putKey != pictureKey {
		t.Fatalf("expected presigner key to match response, got %q", fake.putKey)
	}
	if fake.putContentType != "image/jpeg" {
		t.Fatalf("expected content type image/jpeg, got %q", fake.putContentType)
	}
	if payload.Data.Attributes.UploadURL != "https://upload" {
		t.Fatalf("unexpected upload url %q", payload.Data.Attributes.UploadURL)
	}
	if payload.Data.Attributes.Headers["Content-Type"] != "image/jpeg" {
		t.Fatalf("unexpected headers %#v", payload.Data.Attributes.Headers)
	}
}

func TestUploadsPreview_MethodNotAllowed(t *testing.T) {
	h := NewUploadsHandler(&fakePresigner{}, id.NewGenerator())
	req := httptest.NewRequest(http.MethodPost, "/uploads/preview", nil)
	res := httptest.NewRecorder()

	h.Preview(res, req)

	if res.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected status 405, got %d", res.Code)
	}
}

func TestUploadsPreview_MissingKey(t *testing.T) {
	h := NewUploadsHandler(&fakePresigner{}, id.NewGenerator())
	req := httptest.NewRequest(http.MethodGet, "/uploads/preview", nil)
	res := httptest.NewRecorder()

	h.Preview(res, req)

	if res.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", res.Code)
	}
}

func TestUploadsPreview_PresignError(t *testing.T) {
	fake := &fakePresigner{getErr: errors.New("boom")}
	h := NewUploadsHandler(fake, id.NewGenerator())
	req := httptest.NewRequest(http.MethodGet, "/uploads/preview?picture_key=items/a.png", nil)
	res := httptest.NewRecorder()

	h.Preview(res, req)

	if res.Code != http.StatusInternalServerError {
		t.Fatalf("expected status 500, got %d", res.Code)
	}
}

func TestUploadsPreview_Success(t *testing.T) {
	fake := &fakePresigner{getURL: "https://preview"}
	h := NewUploadsHandler(fake, id.NewGenerator())
	req := httptest.NewRequest(http.MethodGet, "/uploads/preview?picture_key=items/a.png", nil)
	res := httptest.NewRecorder()

	h.Preview(res, req)

	if res.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", res.Code)
	}

	var payload uploadPreviewResponse
	if err := json.NewDecoder(res.Body).Decode(&payload); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if payload.Data.Attributes.PictureKey != "items/a.png" {
		t.Fatalf("unexpected picture key %q", payload.Data.Attributes.PictureKey)
	}
	if payload.Data.Attributes.PreviewURL != "https://preview" {
		t.Fatalf("unexpected preview url %q", payload.Data.Attributes.PreviewURL)
	}
	if fake.getKey != "items/a.png" {
		t.Fatalf("expected presigner key to match, got %q", fake.getKey)
	}
}

func TestUploadsClone_MethodNotAllowed(t *testing.T) {
	h := NewUploadsHandler(&fakePresigner{}, id.NewGenerator())
	req := httptest.NewRequest(http.MethodGet, "/uploads/clone", nil)
	res := httptest.NewRecorder()

	h.Clone(res, req)

	if res.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected status 405, got %d", res.Code)
	}
}

func TestUploadsClone_InvalidContentType(t *testing.T) {
	h := NewUploadsHandler(&fakePresigner{}, id.NewGenerator())
	req := httptest.NewRequest(http.MethodPost, "/uploads/clone", nil)
	req.Header.Set("Content-Type", "text/plain")
	res := httptest.NewRecorder()

	h.Clone(res, req)

	if res.Code != http.StatusUnsupportedMediaType {
		t.Fatalf("expected status 415, got %d", res.Code)
	}
}

func TestUploadsClone_InvalidJSON(t *testing.T) {
	h := NewUploadsHandler(&fakePresigner{}, id.NewGenerator())
	body := bytes.NewBufferString(`{"picture_key":`) // invalid
	req := httptest.NewRequest(http.MethodPost, "/uploads/clone", body)
	req.Header.Set("Content-Type", "application/json")
	res := httptest.NewRecorder()

	h.Clone(res, req)

	if res.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", res.Code)
	}
}

func TestUploadsClone_MissingKey(t *testing.T) {
	h := NewUploadsHandler(&fakePresigner{}, id.NewGenerator())
	body := bytes.NewBufferString(`{"picture_key":" "}`)
	req := httptest.NewRequest(http.MethodPost, "/uploads/clone", body)
	req.Header.Set("Content-Type", "application/json")
	res := httptest.NewRecorder()

	h.Clone(res, req)

	if res.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", res.Code)
	}
}

func TestUploadsClone_CopyError(t *testing.T) {
	fake := &fakePresigner{copyErr: errors.New("boom")}
	h := NewUploadsHandler(fake, id.NewGenerator())
	body := bytes.NewBufferString(`{"picture_key":"items/a.png"}`)
	req := httptest.NewRequest(http.MethodPost, "/uploads/clone", body)
	req.Header.Set("Content-Type", "application/json")
	res := httptest.NewRecorder()

	h.Clone(res, req)

	if res.Code != http.StatusInternalServerError {
		t.Fatalf("expected status 500, got %d", res.Code)
	}
}

func TestUploadsClone_Success(t *testing.T) {
	fake := &fakePresigner{}
	h := NewUploadsHandler(fake, id.NewGenerator())
	body := bytes.NewBufferString(`{"picture_key":"items/a.png"}`)
	req := httptest.NewRequest(http.MethodPost, "/uploads/clone", body)
	req.Header.Set("Content-Type", "application/vnd.api+json")
	res := httptest.NewRecorder()

	h.Clone(res, req)

	if res.Code != http.StatusCreated {
		t.Fatalf("expected status 201, got %d", res.Code)
	}

	var payload cloneResponse
	if err := json.NewDecoder(res.Body).Decode(&payload); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	pictureKey := payload.Data.Attributes.PictureKey
	if !strings.HasPrefix(pictureKey, "items/") {
		t.Fatalf("expected picture key to start with items/, got %q", pictureKey)
	}
	if !strings.HasSuffix(pictureKey, ".png") {
		t.Fatalf("expected picture key to end with .png, got %q", pictureKey)
	}
	if fake.copySource != "items/a.png" {
		t.Fatalf("expected copy source to be items/a.png, got %q", fake.copySource)
	}
	if fake.copyDest != pictureKey {
		t.Fatalf("expected copy dest to match response, got %q", fake.copyDest)
	}
}

func TestIsJSONRequest(t *testing.T) {
	cases := []struct {
		name   string
		input  string
		expect bool
	}{
		{name: "empty", input: "", expect: false},
		{name: "json", input: "application/json", expect: true},
		{name: "json-charset", input: "application/json; charset=utf-8", expect: true},
		{name: "jsonapi", input: "application/vnd.api+json", expect: true},
		{name: "jsonapi-charset", input: "application/vnd.api+json; charset=utf-8", expect: true},
		{name: "text", input: "text/plain", expect: false},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := isJSONRequest(tc.input); got != tc.expect {
				t.Fatalf("expected %v, got %v", tc.expect, got)
			}
		})
	}
}
