package app

import (
	"encoding/json"
	"html/template"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"buildlight"
)

func setupTestServer(t *testing.T) (*httptest.Server, *DB) {
	t.Helper()

	db, _ := setupTestDB(t)
	hub := NewHub()
	go hub.Run()

	// Parse templates for HTML rendering
	var err error
	Templates, err = template.New("").Funcs(TemplateFuncs).ParseFS(buildlight.TemplateDir(), "templates/*.html")
	if err != nil {
		t.Fatalf("Failed to parse templates: %v", err)
	}

	h := &Handler{db: db, hub: hub}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /up", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})
	mux.Handle("GET /public/", buildlight.StaticHandler())
	mux.HandleFunc("GET /ws", h.HandleWebSocket)
	mux.HandleFunc("GET /api/devices/{id}", h.APIDeviceShow)
	mux.HandleFunc("POST /api/device/trigger", h.APIDeviceTrigger)
	mux.HandleFunc("GET /api/device/{id}/red", h.APIRedShow)
	mux.HandleFunc("GET /devices/{id}", h.DeviceShow)
	mux.HandleFunc("POST /", h.WebhookCreate)
	mux.HandleFunc("GET /{id}", h.ColorsShow)
	mux.HandleFunc("GET /{$}", h.ColorsIndex)

	server := httptest.NewServer(mux)
	t.Cleanup(server.Close)

	return server, db
}

func TestColorsIndex(t *testing.T) {
	server, db := setupTestServer(t)
	_, ctx := setupTestDB(t)

	t.Run("returns HTML by default", func(t *testing.T) {
		truncate(t, db, ctx)
		resp, err := http.Get(server.URL + "/")
		if err != nil {
			t.Fatalf("Request error: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != 200 {
			t.Errorf("expected 200, got %d", resp.StatusCode)
		}
		ct := resp.Header.Get("Content-Type")
		if !strings.Contains(ct, "text/html") {
			t.Errorf("expected text/html, got %s", ct)
		}
		body, _ := io.ReadAll(resp.Body)
		if !strings.Contains(string(body), "Buildlight") {
			t.Error("expected HTML to contain Buildlight")
		}
	})

	t.Run("returns JSON when requested", func(t *testing.T) {
		truncate(t, db, ctx)
		createStatus(t, db, ctx, statusOpts{Red: boolPtr(true), Username: "alice"})

		req, _ := http.NewRequest("GET", server.URL+"/?format=json", nil)
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatalf("Request error: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != 200 {
			t.Errorf("expected 200, got %d", resp.StatusCode)
		}

		var colors Colors
		json.NewDecoder(resp.Body).Decode(&colors)
		if colors.Red != 1 {
			t.Errorf("expected red=1, got %d", colors.Red)
		}
	})

	t.Run("returns JSON with Accept header", func(t *testing.T) {
		truncate(t, db, ctx)

		req, _ := http.NewRequest("GET", server.URL+"/", nil)
		req.Header.Set("Accept", "application/json")
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatalf("Request error: %v", err)
		}
		defer resp.Body.Close()

		ct := resp.Header.Get("Content-Type")
		if !strings.Contains(ct, "application/json") {
			t.Errorf("expected application/json, got %s", ct)
		}
	})
}

func TestColorsShow(t *testing.T) {
	server, db := setupTestServer(t)
	_, ctx := setupTestDB(t)

	t.Run("filters by username", func(t *testing.T) {
		truncate(t, db, ctx)
		createStatus(t, db, ctx, statusOpts{Red: boolPtr(true), Username: "alice"})
		createStatus(t, db, ctx, statusOpts{Red: boolPtr(true), Username: "bob"})

		req, _ := http.NewRequest("GET", server.URL+"/alice?format=json", nil)
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatalf("Request error: %v", err)
		}
		defer resp.Body.Close()

		var colors Colors
		json.NewDecoder(resp.Body).Decode(&colors)
		if colors.Red != 1 {
			t.Errorf("expected red=1, got %d", colors.Red)
		}
	})

	t.Run("supports multiple usernames", func(t *testing.T) {
		truncate(t, db, ctx)
		createStatus(t, db, ctx, statusOpts{Red: boolPtr(true), Username: "alice"})
		createStatus(t, db, ctx, statusOpts{Red: boolPtr(true), Username: "bob"})

		req, _ := http.NewRequest("GET", server.URL+"/alice,bob?format=json", nil)
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatalf("Request error: %v", err)
		}
		defer resp.Body.Close()

		var colors Colors
		json.NewDecoder(resp.Body).Decode(&colors)
		if colors.Red != 2 {
			t.Errorf("expected red=2, got %d", colors.Red)
		}
	})
}

func TestDeviceShow(t *testing.T) {
	server, db := setupTestServer(t)
	_, ctx := setupTestDB(t)

	t.Run("shows device by slug", func(t *testing.T) {
		truncate(t, db, ctx)
		createDevice(t, db, ctx, deviceOpts{
			Slug:      "my-device",
			Usernames: []string{"alice"},
		})
		createStatus(t, db, ctx, statusOpts{Red: boolPtr(true), Username: "alice"})

		resp, err := http.Get(server.URL + "/devices/my-device")
		if err != nil {
			t.Fatalf("Request error: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != 200 {
			t.Errorf("expected 200, got %d", resp.StatusCode)
		}
	})

	t.Run("shows device by id", func(t *testing.T) {
		truncate(t, db, ctx)
		d := createDevice(t, db, ctx, deviceOpts{Usernames: []string{"alice"}})

		resp, err := http.Get(server.URL + "/devices/" + d.ID)
		if err != nil {
			t.Fatalf("Request error: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != 200 {
			t.Errorf("expected 200, got %d", resp.StatusCode)
		}
	})

	t.Run("returns 404 for unknown device", func(t *testing.T) {
		truncate(t, db, ctx)
		resp, err := http.Get(server.URL + "/devices/nonexistent")
		if err != nil {
			t.Fatalf("Request error: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != 404 {
			t.Errorf("expected 404, got %d", resp.StatusCode)
		}
	})
}

func TestAPIDeviceShow(t *testing.T) {
	server, db := setupTestServer(t)
	_, ctx := setupTestDB(t)

	t.Run("returns colors and ryg", func(t *testing.T) {
		truncate(t, db, ctx)
		d := createDevice(t, db, ctx, deviceOpts{Usernames: []string{"alice"}})
		createStatus(t, db, ctx, statusOpts{Red: boolPtr(true), Username: "alice"})

		resp, err := http.Get(server.URL + "/api/devices/" + d.ID)
		if err != nil {
			t.Fatalf("Request error: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != 200 {
			t.Errorf("expected 200, got %d", resp.StatusCode)
		}

		var result map[string]any
		json.NewDecoder(resp.Body).Decode(&result)

		ryg, _ := result["ryg"].(string)
		if ryg != "Ryg" {
			t.Errorf("expected ryg=Ryg, got %s", ryg)
		}

		colorsMap, _ := result["colors"].(map[string]any)
		if colorsMap["red"] != true {
			t.Errorf("expected colors.red=true, got %v", colorsMap["red"])
		}
	})

	t.Run("returns 404 for unknown device", func(t *testing.T) {
		truncate(t, db, ctx)
		resp, err := http.Get(server.URL + "/api/devices/00000000-0000-0000-0000-000000000000")
		if err != nil {
			t.Fatalf("Request error: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != 404 {
			t.Errorf("expected 404, got %d", resp.StatusCode)
		}
	})
}

func TestAPIDeviceTrigger(t *testing.T) {
	server, db := setupTestServer(t)
	_, ctx := setupTestDB(t)

	t.Run("accepts coreid form value", func(t *testing.T) {
		truncate(t, db, ctx)
		createDevice(t, db, ctx, deviceOpts{Identifier: "abc123"})

		resp, err := http.PostForm(server.URL+"/api/device/trigger", map[string][]string{
			"coreid": {"abc123"},
		})
		if err != nil {
			t.Fatalf("Request error: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != 200 {
			t.Errorf("expected 200, got %d", resp.StatusCode)
		}
	})

	t.Run("accepts coreid json body", func(t *testing.T) {
		truncate(t, db, ctx)
		createDevice(t, db, ctx, deviceOpts{Identifier: "abc123"})

		body := strings.NewReader(`{"coreid":"abc123"}`)
		resp, err := http.Post(server.URL+"/api/device/trigger", "application/json", body)
		if err != nil {
			t.Fatalf("Request error: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != 200 {
			t.Errorf("expected 200, got %d", resp.StatusCode)
		}
	})
}

func TestAPIRedShow(t *testing.T) {
	server, db := setupTestServer(t)
	_, ctx := setupTestDB(t)

	t.Run("returns JSON list of failing projects", func(t *testing.T) {
		truncate(t, db, ctx)
		d := createDevice(t, db, ctx, deviceOpts{
			Identifier: "device1",
			Usernames:  []string{"alice"},
		})
		createStatus(t, db, ctx, statusOpts{
			Red:         boolPtr(true),
			Username:    "alice",
			ProjectName: "failing-project",
		})

		req, _ := http.NewRequest("GET", server.URL+"/api/device/"+d.Identifier+"/red?format=json", nil)
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatalf("Request error: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != 200 {
			t.Errorf("expected 200, got %d", resp.StatusCode)
		}

		var projects []map[string]string
		json.NewDecoder(resp.Body).Decode(&projects)
		if len(projects) != 1 {
			t.Fatalf("expected 1 project, got %d", len(projects))
		}
		if projects[0]["project_name"] != "failing-project" {
			t.Errorf("expected project_name=failing-project, got %s", projects[0]["project_name"])
		}
	})

	t.Run("returns HTML", func(t *testing.T) {
		truncate(t, db, ctx)
		d := createDevice(t, db, ctx, deviceOpts{
			Identifier: "device2",
			Usernames:  []string{"alice"},
		})
		createStatus(t, db, ctx, statusOpts{
			Red:         boolPtr(true),
			Username:    "alice",
			ProjectName: "broken-project",
		})

		resp, err := http.Get(server.URL + "/api/device/" + d.Identifier + "/red")
		if err != nil {
			t.Fatalf("Request error: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != 200 {
			t.Errorf("expected 200, got %d", resp.StatusCode)
		}

		body, _ := io.ReadAll(resp.Body)
		if !strings.Contains(string(body), "broken-project") {
			t.Error("expected HTML to contain broken-project")
		}
	})
}

func TestWebhookCreate(t *testing.T) {
	server, db := setupTestServer(t)
	_, ctx := setupTestDB(t)

	t.Run("returns 400 for unknown payload", func(t *testing.T) {
		truncate(t, db, ctx)
		resp, err := http.Post(server.URL+"/", "application/json", strings.NewReader(`{"unknown":"payload"}`))
		if err != nil {
			t.Fatalf("Request error: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != 400 {
			t.Errorf("expected 400, got %d", resp.StatusCode)
		}
	})

	t.Run("processes Travis form payload", func(t *testing.T) {
		truncate(t, db, ctx)
		body := "payload=" + loadFixture(t, "travis.json")
		resp, err := http.Post(server.URL+"/", "application/x-www-form-urlencoded", strings.NewReader(body))
		if err != nil {
			t.Fatalf("Request error: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != 200 {
			t.Errorf("expected 200, got %d", resp.StatusCode)
		}

		if count := statusCount(t, db, ctx); count != 1 {
			t.Errorf("expected 1 status, got %d", count)
		}
	})

	t.Run("processes GitHub payload", func(t *testing.T) {
		truncate(t, db, ctx)
		body := loadFixture(t, "github.json")
		resp, err := http.Post(server.URL+"/", "application/json", strings.NewReader(body))
		if err != nil {
			t.Fatalf("Request error: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != 200 {
			t.Errorf("expected 200, got %d", resp.StatusCode)
		}

		if count := statusCount(t, db, ctx); count != 1 {
			t.Errorf("expected 1 status, got %d", count)
		}
	})

	t.Run("processes Circle payload", func(t *testing.T) {
		truncate(t, db, ctx)
		body := loadFixture(t, "circle.json")

		req, _ := http.NewRequest("POST", server.URL+"/", strings.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Circleci-Event-Type", "workflow-completed")
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatalf("Request error: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != 200 {
			t.Errorf("expected 200, got %d", resp.StatusCode)
		}

		if count := statusCount(t, db, ctx); count != 1 {
			t.Errorf("expected 1 status, got %d", count)
		}
	})

	t.Run("Circle skips non-main branch", func(t *testing.T) {
		truncate(t, db, ctx)
		body := loadFixture(t, "circle_pr.json")

		req, _ := http.NewRequest("POST", server.URL+"/", strings.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Circleci-Event-Type", "workflow-completed")
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatalf("Request error: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != 200 {
			t.Errorf("expected 200, got %d", resp.StatusCode)
		}

		if count := statusCount(t, db, ctx); count != 0 {
			t.Errorf("expected 0 statuses for non-main branch, got %d", count)
		}
	})

	t.Run("returns 400 for invalid JSON", func(t *testing.T) {
		truncate(t, db, ctx)
		resp, err := http.Post(server.URL+"/", "application/json", strings.NewReader("not json"))
		if err != nil {
			t.Fatalf("Request error: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != 400 {
			t.Errorf("expected 400, got %d", resp.StatusCode)
		}
	})
}
