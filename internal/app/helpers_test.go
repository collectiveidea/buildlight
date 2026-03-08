package app

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"sync/atomic"
	"testing"

	"buildlight"
)

func TestMain(m *testing.M) {
	buildlight.RootDir = filepath.Join("..", "..")
	os.Exit(m.Run())
}

var (
	testDB   *DB
	testOnce sync.Once
	seq      atomic.Int64
)

func setupTestDB(t *testing.T) (*DB, context.Context) {
	t.Helper()

	testOnce.Do(func() {
		url := os.Getenv("DATABASE_URL")
		if url == "" {
			url = "postgres://localhost/buildlight_test?sslmode=disable"
		}

		ctx := context.Background()
		db, err := NewDB(ctx, url)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Failed to connect to test database: %v\n", err)
			fmt.Fprintf(os.Stderr, "Set DATABASE_URL or create a buildlight_test database\n")
			os.Exit(1)
		}

		if err := db.Migrate(ctx, buildlight.MigrationsFS); err != nil {
			fmt.Fprintf(os.Stderr, "Failed to run migrations: %v\n", err)
			os.Exit(1)
		}

		testDB = db
	})

	ctx := context.Background()
	truncate(t, testDB, ctx)

	return testDB, ctx
}

func truncate(t *testing.T, db *DB, ctx context.Context) {
	t.Helper()
	_, err := db.pool.Exec(ctx, "TRUNCATE statuses, devices RESTART IDENTITY CASCADE")
	if err != nil {
		t.Fatalf("Failed to truncate tables: %v", err)
	}
}

// Factory helpers

type statusOpts struct {
	Service     string
	ProjectID   string
	ProjectName string
	Username    string
	Workflow    string
	Red         *bool
	Yellow      *bool
}

func createStatus(t *testing.T, db *DB, ctx context.Context, opts statusOpts) *Status {
	t.Helper()

	n := seq.Add(1)

	if opts.Service == "" {
		opts.Service = "travis"
	}
	if opts.ProjectID == "" {
		opts.ProjectID = fmt.Sprintf("%d", n)
	}
	if opts.ProjectName == "" {
		opts.ProjectName = fmt.Sprintf("buildlight%d", n)
	}
	if opts.Red == nil {
		opts.Red = boolPtr(false)
	}
	if opts.Yellow == nil {
		opts.Yellow = boolPtr(false)
	}

	s := &Status{
		Service:     opts.Service,
		ProjectID:   opts.ProjectID,
		ProjectName: opts.ProjectName,
		Username:    opts.Username,
		Workflow:    opts.Workflow,
		Red:         opts.Red,
		Yellow:      opts.Yellow,
	}

	err := db.pool.QueryRow(ctx, `
		INSERT INTO statuses (service, project_id, project_name, username, workflow, red, yellow, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW())
		RETURNING id
	`, s.Service, s.ProjectID, s.ProjectName, s.Username, s.Workflow, s.Red, s.Yellow).Scan(&s.ID)
	if err != nil {
		t.Fatalf("Failed to create status: %v", err)
	}

	return s
}

type deviceOpts struct {
	Name       string
	Usernames  []string
	Projects   []string
	Identifier string
	Slug       string
	WebhookURL string
}

func createDevice(t *testing.T, db *DB, ctx context.Context, opts deviceOpts) *Device {
	t.Helper()

	n := seq.Add(1)

	if opts.Name == "" {
		opts.Name = fmt.Sprintf("Device %d", n)
	}
	if opts.Usernames == nil {
		opts.Usernames = []string{}
	}
	if opts.Projects == nil {
		opts.Projects = []string{}
	}
	if opts.Slug == "" {
		opts.Slug = fmt.Sprintf("slug-%d", n)
	}

	var identifier *string
	if opts.Identifier != "" {
		identifier = &opts.Identifier
	}

	var webhookURL *string
	if opts.WebhookURL != "" {
		webhookURL = &opts.WebhookURL
	}

	d := &Device{}
	err := db.pool.QueryRow(ctx, `
		INSERT INTO devices (name, usernames, projects, identifier, slug, webhook_url, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
		RETURNING id, name, usernames, projects, COALESCE(identifier,''), COALESCE(webhook_url,''), COALESCE(slug,''), COALESCE(status,''), status_changed_at, created_at, updated_at
	`, opts.Name, opts.Usernames, opts.Projects, identifier, opts.Slug, webhookURL).Scan(
		&d.ID, &d.Name, &d.Usernames, &d.Projects,
		&d.Identifier, &d.WebhookURL, &d.Slug, &d.Status,
		&d.StatusChangedAt, &d.CreatedAt, &d.UpdatedAt,
	)
	if err != nil {
		t.Fatalf("Failed to create device: %v", err)
	}

	return d
}

func statusCount(t *testing.T, db *DB, ctx context.Context) int {
	t.Helper()
	var count int
	err := db.pool.QueryRow(ctx, "SELECT COUNT(*) FROM statuses").Scan(&count)
	if err != nil {
		t.Fatalf("Failed to count statuses: %v", err)
	}
	return count
}

func loadStatus(t *testing.T, db *DB, ctx context.Context, id int) *Status {
	t.Helper()
	var s Status
	err := db.pool.QueryRow(ctx, `
		SELECT id, service, COALESCE(project_id,''), COALESCE(project_name,''),
		       COALESCE(username,''), COALESCE(workflow,''), red, yellow
		FROM statuses WHERE id = $1
	`, id).Scan(&s.ID, &s.Service, &s.ProjectID, &s.ProjectName,
		&s.Username, &s.Workflow, &s.Red, &s.Yellow)
	if err != nil {
		t.Fatalf("Failed to load status %d: %v", id, err)
	}
	return &s
}

func loadLatestStatus(t *testing.T, db *DB, ctx context.Context) *Status {
	t.Helper()
	var s Status
	err := db.pool.QueryRow(ctx, `
		SELECT id, service, COALESCE(project_id,''), COALESCE(project_name,''),
		       COALESCE(username,''), COALESCE(workflow,''), red, yellow
		FROM statuses ORDER BY created_at DESC LIMIT 1
	`).Scan(&s.ID, &s.Service, &s.ProjectID, &s.ProjectName,
		&s.Username, &s.Workflow, &s.Red, &s.Yellow)
	if err != nil {
		t.Fatalf("Failed to load latest status: %v", err)
	}
	return &s
}

func loadFixture(t *testing.T, name string) string {
	t.Helper()
	data, err := os.ReadFile("testdata/" + name)
	if err != nil {
		t.Fatalf("Failed to read fixture %s: %v", name, err)
	}
	return string(data)
}
