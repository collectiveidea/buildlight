use buildlight::app;
use buildlight::config::Config;
use tracing_subscriber::EnvFilter;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::try_from_default_env().unwrap_or_else(|_| "info".into()))
        .init();

    let config = Config::from_env();
    let addr = format!("0.0.0.0:{}", config.port);

    tracing::info!("Starting BuildLight on {}", addr);

    let app = app::create_app(config).await;

    let listener = tokio::net::TcpListener::bind(&addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
