package app

import (
	"context"
	"fmt"
	"html/template"
	"log"
	"net/http"
	"time"

	"buildlight"
)

var (
	Templates     *template.Template
	TemplateFuncs = template.FuncMap{
		"pluralize": func(count int, singular, plural string) string {
			if count == 1 {
				return fmt.Sprintf("%d %s", count, singular)
			}
			return fmt.Sprintf("%d %s", count, plural)
		},
	}

	AppHost             string
	DebugMode           bool
	ParticleAccessToken string
)

type Config struct {
	DatabaseURL         string
	Port                string
	Host                string
	Debug               bool
	ParticleAccessToken string
}

// ListenAndServe starts the buildlight server. It blocks until the context is
// cancelled, then gracefully shuts down.
func ListenAndServe(ctx context.Context, cfg Config) error {
	// Parse templates
	var err error
	Templates, err = template.New("").Funcs(TemplateFuncs).ParseFS(buildlight.TemplateDir(), "templates/*.html")
	if err != nil {
		return fmt.Errorf("parsing templates: %w", err)
	}

	// Connect to database
	db, err := NewDB(ctx, cfg.DatabaseURL)
	if err != nil {
		return fmt.Errorf("connecting to database: %w", err)
	}
	defer db.Close()

	// Run migrations
	if err := db.Migrate(ctx, buildlight.MigrationsFS); err != nil {
		return fmt.Errorf("running migrations: %w", err)
	}

	// Set globals
	AppHost = cfg.Host
	DebugMode = cfg.Debug
	ParticleAccessToken = cfg.ParticleAccessToken

	// Create WebSocket hub
	hub := NewHub()
	go hub.Run()

	// Create handler
	h := &Handler{db: db, hub: hub}

	// Set up routes
	mux := http.NewServeMux()

	mux.HandleFunc("GET /up", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, "OK")
	})

	mux.Handle("GET /public/", buildlight.StaticHandler())

	mux.HandleFunc("GET /ws", h.HandleWebSocket)

	mux.HandleFunc("GET /api/devices/{id}", h.APIDeviceShow)
	mux.HandleFunc("POST /api/device/trigger", h.APIDeviceTrigger)
	mux.HandleFunc("GET /api/device/{id}/red", h.APIRedShow)

	mux.HandleFunc("GET /devices/{id}", h.DeviceShow)

	mux.HandleFunc("POST /", h.WebhookCreate)

	// Colors - must be last since it catches /{id}
	mux.HandleFunc("GET /{id}", h.ColorsShow)
	mux.HandleFunc("GET /{$}", h.ColorsIndex)

	server := &http.Server{
		Addr:    ":" + cfg.Port,
		Handler: mux,
	}

	go func() {
		log.Printf("Listening on :%s", cfg.Port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server error: %v", err)
		}
	}()

	<-ctx.Done()
	log.Println("Shutting down...")

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer shutdownCancel()
	return server.Shutdown(shutdownCtx)
}
