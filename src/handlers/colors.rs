use axum::extract::State;
use axum::http::header;
use axum::response::{Html, IntoResponse, Response};
use axum::Json;

use crate::app::AppState;
use crate::error::AppError;
use crate::models::status::Status;

/// GET / - Show colors page or JSON for all projects.
pub async fn index(State(state): State<AppState>) -> Result<Response, AppError> {
    render_colors(&state, None, "html").await
}

/// Called from the fallback handler for paths like /collectiveidea or /collectiveidea.json
pub async fn show(state: AppState, raw: String) -> Result<Response, AppError> {
    // Parse format suffix
    let (id_part, format) = if let Some(stripped) = raw.strip_suffix(".json") {
        (stripped.to_string(), "json")
    } else if let Some(stripped) = raw.strip_suffix(".ryg") {
        (stripped.to_string(), "ryg")
    } else {
        (raw, "html")
    };

    let usernames = if id_part.is_empty() {
        None
    } else {
        Some(id_part.split(',').map(String::from).collect())
    };
    render_colors(&state, usernames, format).await
}

async fn render_colors(state: &AppState, usernames: Option<Vec<String>>, format: &str) -> Result<Response, AppError> {
    match format {
        "json" => {
            let colors = Status::colors(&state.pool, usernames.as_deref()).await?;
            Ok(Json(colors).into_response())
        }
        "ryg" => {
            let pool = state.pool.clone();
            let usernames_clone = usernames.clone();

            let stream = async_stream::stream! {
                loop {
                    match Status::ryg(&pool, usernames_clone.as_deref()).await {
                        Ok(ryg) => yield Ok::<_, std::io::Error>(ryg),
                        Err(_) => break,
                    }
                    tokio::time::sleep(std::time::Duration::from_secs(1)).await;
                }
            };

            let body = axum::body::Body::from_stream(stream);
            Ok(Response::builder()
                .header(header::CONTENT_TYPE, "text/ryg")
                .body(body)
                .unwrap()
                .into_response())
        }
        _ => {
            let colors = Status::colors(&state.pool, usernames.as_deref()).await?;
            let html = render_colors_page(state, &colors)?;
            Ok(Html(html).into_response())
        }
    }
}

fn render_colors_page(
    state: &AppState,
    colors: &crate::models::status::Colors,
) -> Result<String, AppError> {
    let mut context = tera::Context::new();
    context.insert("colors", colors);

    let red_count = colors.red.as_i64().unwrap_or(0);
    context.insert("red_count", &red_count);

    let tera = state.tera.read().map_err(|e| AppError::Internal(e.to_string()))?;

    #[cfg(debug_assertions)]
    {
        drop(tera);
        let mut tera = state.tera.write().map_err(|e| AppError::Internal(e.to_string()))?;
        let _ = tera.full_reload();
        Ok(tera.render("colors/index.html", &context)?)
    }

    #[cfg(not(debug_assertions))]
    {
        Ok(tera.render("colors/index.html", &context)?)
    }
}
