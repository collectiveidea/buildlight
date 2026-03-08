package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"

	"buildlight"
	"buildlight/internal/app"
)

func main() {
	if len(os.Args) > 1 && os.Args[1] == "migrate" {
		ctx := context.Background()
		databaseURL := os.Getenv("DATABASE_URL")
		if databaseURL == "" {
			databaseURL = "postgres://localhost/buildlight_development?sslmode=disable"
		}
		db, err := app.NewDB(ctx, databaseURL)
		if err != nil {
			log.Fatal(err)
		}
		defer db.Close()
		if err := db.Migrate(ctx, buildlight.MigrationsFS); err != nil {
			log.Fatal(err)
		}
		log.Println("Migrations complete")
		return
	}

	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer cancel()

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	host := os.Getenv("HOST")
	if host == "" {
		host = "localhost:" + port
	}

	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		databaseURL = "postgres://localhost/buildlight_development?sslmode=disable"
	}

	cfg := app.Config{
		DatabaseURL:         databaseURL,
		Port:                port,
		Host:                host,
		Debug:               os.Getenv("DEBUG") != "",
		ParticleAccessToken: os.Getenv("PARTICLE_ACCESS_TOKEN"),
	}

	if err := app.ListenAndServe(ctx, cfg); err != nil {
		log.Fatal(err)
	}
}
