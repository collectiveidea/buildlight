package app

import (
	"encoding/json"
	"testing"
)

func TestParseCircle(t *testing.T) {
	db, ctx := setupTestDB(t)
	hub := NewHub()

	t.Run("sets colors on success", func(t *testing.T) {
		truncate(t, db, ctx)
		body := loadFixture(t, "circle.json")
		var payload map[string]interface{}
		if err := json.Unmarshal([]byte(body), &payload); err != nil {
			t.Fatalf("Failed to unmarshal fixture: %v", err)
		}

		if err := ParseCircle(ctx, db, hub, payload); err != nil {
			t.Fatalf("ParseCircle error: %v", err)
		}

		s := loadLatestStatus(t, db, ctx)
		if s.Service != "circle" {
			t.Errorf("expected service circle, got %s", s.Service)
		}
		if s.Username != "collectiveidea" {
			t.Errorf("expected username collectiveidea, got %s", s.Username)
		}
		if s.ProjectName != "buildlight" {
			t.Errorf("expected project_name buildlight, got %s", s.ProjectName)
		}
		if *s.Red != false {
			t.Errorf("expected red=false, got %v", *s.Red)
		}
		if *s.Yellow != false {
			t.Errorf("expected yellow=false, got %v", *s.Yellow)
		}
	})

	t.Run("sets colors on failure", func(t *testing.T) {
		truncate(t, db, ctx)
		body := loadFixture(t, "circle.json")
		var payload map[string]interface{}
		json.Unmarshal([]byte(body), &payload)

		// Change workflow status to failed
		workflow := payload["workflow"].(map[string]interface{})
		workflow["status"] = "failed"

		if err := ParseCircle(ctx, db, hub, payload); err != nil {
			t.Fatalf("ParseCircle error: %v", err)
		}

		s := loadLatestStatus(t, db, ctx)
		if *s.Red != true {
			t.Errorf("expected red=true, got %v", *s.Red)
		}
		if *s.Yellow != false {
			t.Errorf("expected yellow=false, got %v", *s.Yellow)
		}
	})

	t.Run("ignores non-main branches", func(t *testing.T) {
		truncate(t, db, ctx)
		body := loadFixture(t, "circle_pr.json")
		var payload map[string]interface{}
		json.Unmarshal([]byte(body), &payload)

		if err := ParseCircle(ctx, db, hub, payload); err != nil {
			t.Fatalf("ParseCircle error: %v", err)
		}

		if count := statusCount(t, db, ctx); count != 0 {
			t.Errorf("expected 0 statuses, got %d", count)
		}
	})

	t.Run("ignores non-workflow-completed events", func(t *testing.T) {
		truncate(t, db, ctx)
		payload := map[string]interface{}{
			"type": "job-completed",
		}

		if err := ParseCircle(ctx, db, hub, payload); err != nil {
			t.Fatalf("ParseCircle error: %v", err)
		}

		if count := statusCount(t, db, ctx); count != 0 {
			t.Errorf("expected 0 statuses, got %d", count)
		}
	})
}

func TestParseGithub(t *testing.T) {
	db, ctx := setupTestDB(t)
	hub := NewHub()

	t.Run("creates a status", func(t *testing.T) {
		truncate(t, db, ctx)
		body := loadFixture(t, "github.json")
		var payload map[string]interface{}
		json.Unmarshal([]byte(body), &payload)

		if err := ParseGithub(ctx, db, hub, payload); err != nil {
			t.Fatalf("ParseGithub error: %v", err)
		}

		if count := statusCount(t, db, ctx); count != 1 {
			t.Errorf("expected 1 status, got %d", count)
		}

		s := loadLatestStatus(t, db, ctx)
		if s.Service != "github" {
			t.Errorf("expected service github, got %s", s.Service)
		}
		if s.Username != "collectiveidea" {
			t.Errorf("expected username collectiveidea, got %s", s.Username)
		}
		if s.ProjectName != "buildlight" {
			t.Errorf("expected project_name buildlight, got %s", s.ProjectName)
		}
		if s.Workflow != "CI" {
			t.Errorf("expected workflow CI, got %s", s.Workflow)
		}
	})

	t.Run("sets green on success", func(t *testing.T) {
		truncate(t, db, ctx)
		payload := map[string]interface{}{
			"repository": "owner/repo",
			"status":     "success",
			"workflow":   "CI",
		}

		if err := ParseGithub(ctx, db, hub, payload); err != nil {
			t.Fatalf("ParseGithub error: %v", err)
		}

		s := loadLatestStatus(t, db, ctx)
		if *s.Red != false {
			t.Errorf("expected red=false, got %v", *s.Red)
		}
		if *s.Yellow != false {
			t.Errorf("expected yellow=false, got %v", *s.Yellow)
		}
	})

	t.Run("sets red on failure", func(t *testing.T) {
		truncate(t, db, ctx)
		payload := map[string]interface{}{
			"repository": "owner/repo",
			"status":     "failure",
			"workflow":   "CI",
		}

		if err := ParseGithub(ctx, db, hub, payload); err != nil {
			t.Fatalf("ParseGithub error: %v", err)
		}

		s := loadLatestStatus(t, db, ctx)
		if *s.Red != true {
			t.Errorf("expected red=true, got %v", *s.Red)
		}
		if *s.Yellow != false {
			t.Errorf("expected yellow=false, got %v", *s.Yellow)
		}
	})

	t.Run("sets yellow on empty status", func(t *testing.T) {
		truncate(t, db, ctx)
		payload := map[string]interface{}{
			"repository": "owner/repo",
			"status":     "",
			"workflow":   "CI",
		}

		if err := ParseGithub(ctx, db, hub, payload); err != nil {
			t.Fatalf("ParseGithub error: %v", err)
		}

		s := loadLatestStatus(t, db, ctx)
		if *s.Yellow != true {
			t.Errorf("expected yellow=true, got %v", *s.Yellow)
		}
	})

	t.Run("upserts existing status", func(t *testing.T) {
		truncate(t, db, ctx)
		payload := map[string]interface{}{
			"repository": "owner/repo",
			"status":     "failure",
			"workflow":   "CI",
		}

		ParseGithub(ctx, db, hub, payload)
		if count := statusCount(t, db, ctx); count != 1 {
			t.Fatalf("expected 1 status, got %d", count)
		}

		payload["status"] = "success"
		ParseGithub(ctx, db, hub, payload)

		if count := statusCount(t, db, ctx); count != 1 {
			t.Errorf("expected 1 status after upsert, got %d", count)
		}

		s := loadLatestStatus(t, db, ctx)
		if *s.Red != false {
			t.Errorf("expected red=false after upsert, got %v", *s.Red)
		}
	})
}

func TestParseTravis(t *testing.T) {
	db, ctx := setupTestDB(t)
	hub := NewHub()

	t.Run("sets green on Passed", func(t *testing.T) {
		truncate(t, db, ctx)
		body := loadFixture(t, "travis.json")
		if err := ParseTravis(ctx, db, hub, body); err != nil {
			t.Fatalf("ParseTravis error: %v", err)
		}

		s := loadLatestStatus(t, db, ctx)
		if s.Service != "travis" {
			t.Errorf("expected service travis, got %s", s.Service)
		}
		if s.Username != "collectiveidea" {
			t.Errorf("expected username collectiveidea, got %s", s.Username)
		}
		if s.ProjectName != "buildlight" {
			t.Errorf("expected project_name buildlight, got %s", s.ProjectName)
		}
		if *s.Red != false {
			t.Errorf("expected red=false, got %v", *s.Red)
		}
		if *s.Yellow != false {
			t.Errorf("expected yellow=false, got %v", *s.Yellow)
		}
	})

	t.Run("sets green on Fixed", func(t *testing.T) {
		truncate(t, db, ctx)
		payload := `{"status_message":"Fixed","repository":{"id":1,"name":"repo","owner_name":"owner"},"type":"push"}`
		if err := ParseTravis(ctx, db, hub, payload); err != nil {
			t.Fatalf("ParseTravis error: %v", err)
		}

		s := loadLatestStatus(t, db, ctx)
		if *s.Red != false {
			t.Errorf("expected red=false, got %v", *s.Red)
		}
	})

	t.Run("sets yellow on Pending", func(t *testing.T) {
		truncate(t, db, ctx)
		payload := `{"status_message":"Pending","repository":{"id":1,"name":"repo","owner_name":"owner"},"type":"push"}`
		if err := ParseTravis(ctx, db, hub, payload); err != nil {
			t.Fatalf("ParseTravis error: %v", err)
		}

		s := loadLatestStatus(t, db, ctx)
		if *s.Yellow != true {
			t.Errorf("expected yellow=true, got %v", *s.Yellow)
		}
	})

	t.Run("sets red on Failed", func(t *testing.T) {
		truncate(t, db, ctx)
		payload := `{"status_message":"Failed","repository":{"id":1,"name":"repo","owner_name":"owner"},"type":"push"}`
		if err := ParseTravis(ctx, db, hub, payload); err != nil {
			t.Fatalf("ParseTravis error: %v", err)
		}

		s := loadLatestStatus(t, db, ctx)
		if *s.Red != true {
			t.Errorf("expected red=true, got %v", *s.Red)
		}
	})

	t.Run("sets red on Broken", func(t *testing.T) {
		truncate(t, db, ctx)
		payload := `{"status_message":"Broken","repository":{"id":1,"name":"repo","owner_name":"owner"},"type":"push"}`
		if err := ParseTravis(ctx, db, hub, payload); err != nil {
			t.Fatalf("ParseTravis error: %v", err)
		}

		s := loadLatestStatus(t, db, ctx)
		if *s.Red != true {
			t.Errorf("expected red=true, got %v", *s.Red)
		}
	})

	t.Run("ignores pull requests", func(t *testing.T) {
		truncate(t, db, ctx)
		payload := `{"status_message":"Passed","type":"pull_request","repository":{"id":1,"name":"repo","owner_name":"owner"}}`
		if err := ParseTravis(ctx, db, hub, payload); err != nil {
			t.Fatalf("ParseTravis error: %v", err)
		}

		if count := statusCount(t, db, ctx); count != 0 {
			t.Errorf("expected 0 statuses for pull_request, got %d", count)
		}
	})
}
