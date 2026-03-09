use axum::Router;
use buildlight::app;
use buildlight::config::Config;
use sqlx::PgPool;

pub fn test_config() -> Config {
    Config {
        database_url: String::new(), // Not used; pool is provided directly
        port: 3001,
        host: "localhost:3001".into(),
        particle_access_token: None,
    }
}

pub fn test_app(pool: PgPool) -> Router {
    let config = test_config();
    app::build_router(config, pool)
}

pub async fn create_status(
    pool: &PgPool,
    service: &str,
    username: Option<&str>,
    project_name: Option<&str>,
    red: bool,
    yellow: bool,
) -> i64 {
    let row: (i64,) = sqlx::query_as(
        "INSERT INTO statuses (service, username, project_name, red, yellow, created_at, updated_at) \
         VALUES ($1, $2, $3, $4, $5, NOW(), NOW()) RETURNING id",
    )
    .bind(service)
    .bind(username)
    .bind(project_name)
    .bind(red)
    .bind(yellow)
    .fetch_one(pool)
    .await
    .unwrap();
    row.0
}

pub async fn create_status_full(
    pool: &PgPool,
    service: &str,
    project_id: Option<&str>,
    username: Option<&str>,
    project_name: Option<&str>,
    workflow: Option<&str>,
    red: bool,
    yellow: bool,
) -> i64 {
    let row: (i64,) = sqlx::query_as(
        "INSERT INTO statuses (service, project_id, username, project_name, workflow, red, yellow, created_at, updated_at) \
         VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW()) RETURNING id",
    )
    .bind(service)
    .bind(project_id)
    .bind(username)
    .bind(project_name)
    .bind(workflow)
    .bind(red)
    .bind(yellow)
    .fetch_one(pool)
    .await
    .unwrap();
    row.0
}

pub async fn create_device(
    pool: &PgPool,
    name: &str,
    slug: Option<&str>,
    usernames: &[&str],
    projects: &[&str],
    identifier: Option<&str>,
    webhook_url: Option<&str>,
) -> uuid::Uuid {
    let usernames: Vec<String> = usernames.iter().map(|s| s.to_string()).collect();
    let projects: Vec<String> = projects.iter().map(|s| s.to_string()).collect();

    let row: (uuid::Uuid,) = sqlx::query_as(
        "INSERT INTO devices (name, slug, usernames, projects, identifier, webhook_url, created_at, updated_at) \
         VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW()) RETURNING id",
    )
    .bind(name)
    .bind(slug)
    .bind(&usernames)
    .bind(&projects)
    .bind(identifier)
    .bind(webhook_url)
    .fetch_one(pool)
    .await
    .unwrap();
    row.0
}
