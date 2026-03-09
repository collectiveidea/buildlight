# BuildLight

[![Github Actions](https://github.com/collectiveidea/buildlight/actions/workflows/ci.yml/badge.svg)](https://github.com/collectiveidea/buildlight/actions/workflows/ci.yml)

Catches webhooks from build services (GitHub Actions, Travis CI, Circle CI, etc.) and provides data to power our office stoplight.

![Collective Idea stoplight](https://buildlight.collectiveidea.com/collectiveidea.gif)

## Setup

### Prerequisites

- Rust (see `Cargo.toml` for edition)
- PostgreSQL

### Install sqlx-cli

```bash
cargo install sqlx-cli --no-default-features --features postgres
```

### Database

Create the database and run migrations:

```bash
createdb buildlight_development
sqlx migrate run
```

Copy `.env.example` to `.env` and update `DATABASE_URL` if needed.

### Run

```bash
cargo run
```

### Test

Tests use `sqlx::test` which automatically creates and destroys temporary databases. Set `DATABASE_URL` to any connectable PostgreSQL database:

```bash
cargo test
```

## Migrations

Migrations live in `migrations/` as SQL files managed by [SQLx](https://github.com/launchbadge/sqlx).

### Create a new migration

```bash
sqlx migrate add -r <name>
```

This creates a pair of files:
- `migrations/<timestamp>_<name>.up.sql` — applied when migrating forward
- `migrations/<timestamp>_<name>.down.sql` — applied when rolling back

Write your SQL in each file, then run:

```bash
sqlx migrate run
```

### Rollback

```bash
sqlx migrate revert
```

### Migrations in production

Migrations run automatically on app startup. No manual step is needed during deploy.

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

## License

This software is © Copyright [Collective Idea](http://collectiveidea.com) and released under the MIT License.
