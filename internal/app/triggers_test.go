package app

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestTriggerWebhook(t *testing.T) {
	t.Run("sends correct body and headers", func(t *testing.T) {
		var gotBody []byte
		var gotHeaders http.Header

		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			gotBody, _ = io.ReadAll(r.Body)
			gotHeaders = r.Header
			w.WriteHeader(http.StatusOK)
		}))
		defer server.Close()

		AppHost = "buildlight.example.com"

		d := &Device{
			ID:         "test-device-id",
			Name:       "Test Device",
			WebhookURL: server.URL,
		}
		colors := Colors{Red: 1, Yellow: false, Green: false}

		TriggerWebhook(d, colors)

		// Check body
		var body map[string]interface{}
		if err := json.Unmarshal(gotBody, &body); err != nil {
			t.Fatalf("Failed to parse body: %v", err)
		}
		colorsMap, ok := body["colors"].(map[string]interface{})
		if !ok {
			t.Fatal("expected colors in body")
		}
		if colorsMap["red"] != true {
			t.Errorf("expected body colors.red=true, got %v", colorsMap["red"])
		}
		if colorsMap["yellow"] != false {
			t.Errorf("expected body colors.yellow=false, got %v", colorsMap["yellow"])
		}
		if colorsMap["green"] != false {
			t.Errorf("expected body colors.green=false, got %v", colorsMap["green"])
		}

		// Check headers
		if got := gotHeaders.Get("Content-Type"); got != "application/json" {
			t.Errorf("expected Content-Type application/json, got %s", got)
		}
		if got := gotHeaders.Get("x-ryg"); got != "Ryg" {
			t.Errorf("expected x-ryg Ryg, got %s", got)
		}
		if got := gotHeaders.Get("x-device-url"); got != "https://buildlight.example.com/api/devices/test-device-id" {
			t.Errorf("expected x-device-url with device id, got %s", got)
		}
	})
}
