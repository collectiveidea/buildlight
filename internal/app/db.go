package app

import (
	"context"
	"fmt"
	"io/fs"
	"log"
	"sort"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
)

type DB struct {
	pool *pgxpool.Pool
}

func NewDB(ctx context.Context, databaseURL string) (*DB, error) {
	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		return nil, fmt.Errorf("connecting to database: %w", err)
	}
	if err := pool.Ping(ctx); err != nil {
		return nil, fmt.Errorf("pinging database: %w", err)
	}
	return &DB{pool: pool}, nil
}

func (db *DB) Close() {
	db.pool.Close()
}

// Migrate runs pending SQL migrations using Rails' schema_migrations table format.
// Each applied migration is tracked as a version string (the timestamp prefix),
// so Rails and Go share the same migration state.
func (db *DB) Migrate(ctx context.Context, migrationsFS fs.FS) error {
	// Ensure schema_migrations table exists (matches Rails' format)
	_, err := db.pool.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS schema_migrations (
			version VARCHAR NOT NULL
		)
	`)
	if err != nil {
		return fmt.Errorf("creating schema_migrations table: %w", err)
	}
	_, err = db.pool.Exec(ctx, `
		CREATE UNIQUE INDEX IF NOT EXISTS unique_schema_migrations ON schema_migrations (version)
	`)
	if err != nil {
		return fmt.Errorf("creating schema_migrations index: %w", err)
	}

	// Load applied versions
	applied := make(map[string]bool)
	rows, err := db.pool.Query(ctx, "SELECT version FROM schema_migrations")
	if err != nil {
		return fmt.Errorf("querying schema_migrations: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var v string
		if err := rows.Scan(&v); err != nil {
			return err
		}
		applied[v] = true
	}
	if err := rows.Err(); err != nil {
		return err
	}

	// Read migration files, sorted by name
	entries, err := fs.ReadDir(migrationsFS, "migrations")
	if err != nil {
		return fmt.Errorf("reading migrations dir: %w", err)
	}
	sort.Slice(entries, func(i, j int) bool {
		return entries[i].Name() < entries[j].Name()
	})

	for _, entry := range entries {
		name := entry.Name()
		if !strings.HasSuffix(name, ".sql") {
			continue
		}

		// Extract version (timestamp prefix before first underscore)
		version := strings.SplitN(strings.TrimSuffix(name, ".sql"), "_", 2)[0]

		if applied[version] {
			continue
		}

		sql, err := fs.ReadFile(migrationsFS, "migrations/"+name)
		if err != nil {
			return fmt.Errorf("reading migration %s: %w", name, err)
		}

		log.Printf("Running migration %s", name)

		tx, err := db.pool.Begin(ctx)
		if err != nil {
			return fmt.Errorf("beginning transaction for %s: %w", name, err)
		}

		if _, err := tx.Exec(ctx, string(sql)); err != nil {
			tx.Rollback(ctx)
			return fmt.Errorf("executing migration %s: %w", name, err)
		}

		if _, err := tx.Exec(ctx, "INSERT INTO schema_migrations (version) VALUES ($1)", version); err != nil {
			tx.Rollback(ctx)
			return fmt.Errorf("recording migration %s: %w", name, err)
		}

		if err := tx.Commit(ctx); err != nil {
			return fmt.Errorf("committing migration %s: %w", name, err)
		}
	}

	return nil
}
