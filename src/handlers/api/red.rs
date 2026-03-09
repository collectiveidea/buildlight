use axum::extract::{Path, State};
use axum::response::{Html, IntoResponse, Response};
use axum::Json;

use crate::app::AppState;
use crate::error::AppError;
use crate::models::device::Device;
use crate::models::status::Status;

#[derive(serde::Serialize)]
struct RedProject {
    username: Option<String>,
    project_name: Option<String>,
}

/// GET /api/device/:id/red - Show failing projects (HTML).
pub async fn show(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> Result<Response, AppError> {
    render_red(&state, &id, "html").await
}

/// GET /api/device/:id/red.json - Show failing projects (JSON).
pub async fn show_json(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> Result<Response, AppError> {
    render_red(&state, &id, "json").await
}

async fn render_red(state: &AppState, id: &str, format: &str) -> Result<Response, AppError> {
    let device = sqlx::query_as::<_, Device>("SELECT * FROM devices WHERE identifier = $1")
        .bind(id)
        .fetch_one(&state.pool)
        .await?;

    let statuses = device.statuses(&state.pool).await?;
    let red_projects: Vec<&Status> = statuses.iter().filter(|s| s.red == Some(true)).collect();

    match format {
        "json" => {
            let json: Vec<RedProject> = red_projects
                .iter()
                .map(|s| RedProject {
                    username: s.username.clone(),
                    project_name: s.project_name.clone(),
                })
                .collect();
            Ok(Json(json).into_response())
        }
        _ => {
            let mut context = tera::Context::new();
            let projects: Vec<serde_json::Value> = red_projects
                .iter()
                .map(|s| {
                    serde_json::json!({
                        "project_name": s.project_name,
                        "username": s.username,
                    })
                })
                .collect();
            context.insert("red_projects", &projects);

            let tera = state.tera.read().map_err(|e| AppError::Internal(e.to_string()))?;

            #[cfg(debug_assertions)]
            {
                drop(tera);
                let mut tera = state.tera.write().map_err(|e| AppError::Internal(e.to_string()))?;
                let _ = tera.full_reload();
                let html = tera.render("api/red.html", &context)?;
                Ok(Html(html).into_response())
            }

            #[cfg(not(debug_assertions))]
            {
                let html = tera.render("api/red.html", &context)?;
                Ok(Html(html).into_response())
            }
        }
    }
}
