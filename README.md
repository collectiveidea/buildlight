# BuildLight

[![Github Actions](https://github.com/collectiveidea/buildlight/actions/workflows/ci.yml/badge.svg)](https://github.com/collectiveidea/buildlight/actions/workflows/ci.yml)[![Build Status](https://travis-ci.org/collectiveidea/buildlight.svg?branch=master)](https://travis-ci.org/collectiveidea/buildlight) [![CircleCI](https://circleci.com/gh/collectiveidea/buildlight.svg?style=shield)](https://circleci.com/gh/collectiveidea/buildlight) [![Ruby Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/testdouble/standard)

Catches webhooks from build services (GitHub Actions, Travis CI, Circle CI, etc.) and provides data to power our office stoplight.

![Collective Idea stoplight](https://buildlight.collectiveidea.com/collectiveidea.gif)

## Add Projects

### GitHub Actions

We assume you have one or more GitHub Action workflow(s) you use. You'll need their `name` below in the `workflows` section.

Copy this to `.github/workflows/buildlight.yml` :

```yaml
name: Buildlight

on:
  workflow_run:
    workflows: [Run Tests] # Replace with your GitHub Action's name(s)
    branches: [main] # Your default branch.

jobs:
  buildlight:
    runs-on: ubuntu-latest
    steps:
      - uses: collectiveidea/buildlight@main
```

### Travis CI

Simply add this to your `.travis.yml` file:

```yaml
notifications:
  webhooks:
    urls:
      - https://buildlight.collectiveidea.com/
    on_start: always
```

### Circle CI

Go to your project settings in Circle CI and add a new Webhook with `https://buildlight.collectiveidea.com` as the Receiver URL. Ensure the the "Workflow Completed" event is checked.

## Viewing Status

The [main website](https://buildlight.collectiveidea.com/) shows the basic status for all projects. Adding a user/organization name to the url shows just those projects, for example: [https://buildlight.collectiveidea.com/collectiveidea](https://buildlight.collectiveidea.com/collectiveidea).

Devices (editable only manually for now) can aggregate multiple organizations & projects, and have their own URL. For example, our office's physical light (see gif above) aggregates [@collectiveidea](https://github.com/collectiveidea), [@deadmanssnitch](https://github.com/deadmanssnitch), and client projects. Its URL is: https://buildlight.collectiveidea.com/devices/collectiveidea-office

## Development

### Requirements

- [Zig 0.15](https://ziglang.org) (install via [mise](https://mise.jdx.dev): `mise install`)
- PostgreSQL

### Quick Start

```bash
mise install                # Install Zig 0.15
createdb buildlight_development
zig build run               # Migrations run automatically
```

The server starts on http://localhost:8080.

In debug mode, templates and static files are read from disk — edit HTML, CSS, or
JS and refresh without recompiling.

### Configuration

All configuration is via environment variables:

| Variable | Default | Description |
|---|---|---|
| `PORT` | `8080` | HTTP listen port |
| `DATABASE_URL` | `postgres://localhost/buildlight_development?sslmode=disable` | PostgreSQL URL |
| `HOST` | `localhost` | Hostname for webhook trigger headers |
| `PARTICLE_ACCESS_TOKEN` | _(none)_ | Particle.io API token for device triggers |
| `DEBUG` | _(unset)_ | Store raw webhook payloads when set |

### Testing

```bash
createdb buildlight_test
zig build test

# Or with an explicit database URL:
TEST_DATABASE_URL="postgresql://user:pass@localhost/buildlight_test" zig build test
```

### Database Migrations

Migrations run automatically on startup. To run them explicitly (e.g. during deploy):

```bash
buildlight migrate
```

Migration files are SQL in `src/migrations/` and are embedded in the binary at
compile time. To add a new migration:

1. Create `src/migrations/NNN_description.sql`
2. Register it in `src/db.zig`:
   ```zig
   const migrations = .{
       .{ .version = "001", .sql = @embedFile("migrations/001_initial_schema.sql") },
       .{ .version = "002", .sql = @embedFile("migrations/002_your_migration.sql") },
   };
   ```
3. Rebuild — the new migration is embedded in the binary

Migrations are tracked in `schema_migrations` and are idempotent.

### Project Structure

```
src/
  main.zig        Entry point, server setup, route registration
  handlers.zig    HTTP request handlers
  models.zig      Database queries, types (Colors, Status, Device)
  parsers.zig     Webhook payload parsing (GitHub, Travis, CircleCI)
  websocket.zig   WebSocket hub and client (pub/sub broadcasting)
  templates.zig   HTML template rendering
  triggers.zig    External notifications (webhooks, Particle.io)
  db.zig          Database pool and migrations
  migrations/     SQL migration files
templates/        HTML templates (embedded in release, disk in debug)
public/           Static assets (CSS, JS, favicons)
build.zig         Build configuration
build.zig.zon     Package dependencies
```

### Debug vs Release

**Debug** (`zig build`): Templates and static files read from disk. Edit and
refresh without recompiling. ~50MB binary.

**Release** (`zig build -Doptimize=ReleaseSafe`): Everything embedded via
`@embedFile`. Single static binary, no runtime file dependencies.

## Deployment (Fly.io)

```bash
flyctl deploy
```

The `Dockerfile` builds a two-stage image:
1. Zig compiles with `ReleaseSafe`
2. Runtime is `debian:stable-slim` + `ca-certificates`

`fly.toml` runs `buildlight migrate` as the release command. Static files under
`/public` are served by Fly's CDN via `[[statics]]`.

## API

### Routes

| Method | Path | Description |
|---|---|---|
| `GET` | `/` | Dashboard HTML or JSON (`Accept: application/json`) |
| `GET` | `/:id` | Colors for username(s), comma-separated |
| `GET` | `/:id.ryg` | Streaming RYG (chunked, 1s updates) |
| `GET` | `/:id.json` | Colors JSON for username(s) |
| `POST` | `/` | Webhook endpoint (GitHub/Travis/CircleCI) |
| `GET` | `/devices/:id` | Device page (by slug or UUID) |
| `GET` | `/api/devices/:id` | Device colors JSON (by UUID) |
| `POST` | `/api/device/trigger` | Trigger device notifications (`coreid=ID`) |
| `GET` | `/api/device/:id/red` | Failing projects for device (by identifier) |
| `GET` | `/ws` | WebSocket |
| `GET` | `/up` | Health check |

### WebSocket Protocol

Connect to `/ws` and send JSON to subscribe:

```json
{"subscribe": "colors:*"}
{"subscribe": "colors:collectiveidea"}
{"subscribe": "device:my-slug"}
```

Server broadcasts:
```json
{"channel": "colors:*", "data": {"colors": {"red": false, "yellow": true, "green": true}}}
```

## License

This software is © Copyright [Collective Idea](http://collectiveidea.com) and released under the MIT License.
