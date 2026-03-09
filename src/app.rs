use std::sync::{Arc, RwLock};

use axum::Router;
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::routing::{get, post};
use sqlx::PgPool;
use sqlx::postgres::PgPoolOptions;
use tera::Tera;
use tokio::sync::broadcast;

use crate::config::Config;
use crate::handlers;
use crate::ws;

#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
    pub tera: Arc<RwLock<Tera>>,
    pub config: Config,
    pub broadcaster: broadcast::Sender<ws::BroadcastMsg>,
    pub http_client: reqwest::Client,
}

pub async fn create_app(config: Config) -> Router {
    let pool = PgPoolOptions::new()
        .max_connections(15)
        .connect(&config.database_url)
        .await
        .expect("Failed to connect to database");

    create_app_with_pool(config, pool).await
}

pub async fn create_app_with_pool(config: Config, pool: PgPool) -> Router {
    sqlx::migrate!("./migrations")
        .run(&pool)
        .await
        .expect("Failed to run migrations");

    build_router(config, pool)
}

/// Build the router without running migrations. Used in tests where
/// sqlx::test has already applied migrations.
pub fn build_router(config: Config, pool: PgPool) -> Router {
    // Load templates
    let template_glob = concat!(env!("CARGO_MANIFEST_DIR"), "/templates/**/*.html");
    let tera = Tera::new(template_glob).expect("Failed to load templates");

    let (tx, _rx) = broadcast::channel::<ws::BroadcastMsg>(256);

    let state = AppState {
        pool,
        tera: Arc::new(RwLock::new(tera)),
        config,
        broadcaster: tx,
        http_client: reqwest::Client::new(),
    };

    Router::new()
        // Health check
        .route("/up", get(handlers::health::health_check))
        // WebSocket
        .route("/ws", get(ws::ws_handler))
        // API routes
        .route("/api/devices/{id}", get(handlers::api::devices::show))
        .route("/api/device/trigger", post(handlers::api::devices::trigger))
        .route("/api/device/{id}/red", get(handlers::api::red::show))
        .route("/api/device/{id}/red.json", get(handlers::api::red::show_json))
        // Device routes
        .route("/devices/{id}", get(handlers::devices::show))
        // Root: GET = colors index, POST = webhook ingestion
        .route("/", get(handlers::colors::index).post(handlers::webhooks::create))
        // Fallback: try public/ static files, then treat as colors show
        .fallback(fallback_handler)
        .with_state(state)
}

/// Handles all unmatched routes: serves static files from public/ or
/// treats the path as a colors show request (e.g., /collectiveidea.json).
async fn fallback_handler(
    state: axum::extract::State<AppState>,
    req: axum::extract::Request,
) -> axum::response::Response {
    let path = req.uri().path().to_string();

    // Try to serve from public/
    let file_path = format!("{}/public{}", env!("CARGO_MANIFEST_DIR"), path);
    if let Ok(contents) = tokio::fs::read(&file_path).await {
        let content_type = match std::path::Path::new(&path)
            .extension()
            .and_then(|e| e.to_str())
        {
            Some("ico") => "image/x-icon",
            Some("png") => "image/png",
            Some("svg") => "image/svg+xml",
            Some("gif") => "image/gif",
            Some("html") => "text/html; charset=utf-8",
            Some("txt") => "text/plain",
            Some("css") => "text/css",
            Some("js") => "application/javascript",
            _ => "application/octet-stream",
        };
        return (
            StatusCode::OK,
            [(axum::http::header::CONTENT_TYPE, content_type)],
            contents,
        )
            .into_response();
    }

    // Otherwise treat as colors show (e.g., /collectiveidea or /collectiveidea.json)
    let ids = path.trim_start_matches('/').to_string();
    if !ids.is_empty() {
        match handlers::colors::show(state.0, ids).await {
            Ok(response) => return response,
            Err(e) => return e.into_response(),
        }
    }

    StatusCode::NOT_FOUND.into_response()
}
