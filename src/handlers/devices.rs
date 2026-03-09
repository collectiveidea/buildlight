use axum::extract::{Path, State};
use axum::response::{Html, IntoResponse, Response};
use axum::Json;

use crate::app::AppState;
use crate::error::AppError;
use crate::models::device::Device;

/// GET /devices/:id - Show device colors as HTML or JSON.
pub async fn show(
    State(state): State<AppState>,
    Path(slug_or_id): Path<String>,
) -> Result<Response, AppError> {
    let (id_part, format) = if let Some(stripped) = slug_or_id.strip_suffix(".json") {
        (stripped.to_string(), "json")
    } else {
        (slug_or_id, "html")
    };

    let device = Device::find_by_slug_or_id(&state.pool, &id_part).await?;
    let colors = device.colors(&state.pool).await?;

    match format {
        "json" => Ok(Json(colors).into_response()),
        _ => {
            let mut context = tera::Context::new();
            context.insert("colors", &colors);
            let red_count = colors.red.as_i64().unwrap_or(0);
            context.insert("red_count", &red_count);

            let tera = state.tera.read().map_err(|e| AppError::Internal(e.to_string()))?;

            #[cfg(debug_assertions)]
            {
                drop(tera);
                let mut tera = state.tera.write().map_err(|e| AppError::Internal(e.to_string()))?;
                let _ = tera.full_reload();
                let html = tera.render("colors/index.html", &context)?;
                Ok(Html(html).into_response())
            }

            #[cfg(not(debug_assertions))]
            {
                let html = tera.render("colors/index.html", &context)?;
                Ok(Html(html).into_response())
            }
        }
    }
}
