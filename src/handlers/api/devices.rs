use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::Json;
use serde::Deserialize;

use crate::app::AppState;
use crate::error::AppError;
use crate::models::device::Device;
use crate::services::{trigger_particle, trigger_webhook};

#[derive(serde::Serialize)]
pub struct DeviceResponse {
    colors: crate::models::status::ColorsAsBooleans,
    ryg: String,
}

/// GET /api/devices/:id - Show device colors and RYG as JSON.
pub async fn show(
    State(state): State<AppState>,
    Path(id): Path<uuid::Uuid>,
) -> Result<Json<DeviceResponse>, AppError> {
    let device = sqlx::query_as::<_, Device>("SELECT * FROM devices WHERE id = $1")
        .bind(id)
        .fetch_one(&state.pool)
        .await?;

    let colors = device.colors_as_booleans(&state.pool).await?;
    let ryg = device.ryg(&state.pool).await?;

    Ok(Json(DeviceResponse { colors, ryg }))
}

#[derive(Deserialize)]
pub struct TriggerParams {
    pub coreid: Option<String>,
}

/// POST /api/device/trigger - Trigger a device (from Particle).
pub async fn trigger(
    State(state): State<AppState>,
    Json(params): Json<TriggerParams>,
) -> StatusCode {
    let Some(ref coreid) = params.coreid else {
        return StatusCode::OK;
    };

    let device = match Device::find_by_identifier(&state.pool, coreid).await {
        Ok(Some(d)) => d,
        _ => return StatusCode::OK,
    };

    // Trigger webhooks and particle
    if device.webhook_url.is_some() {
        if let (Ok(colors), Ok(ryg)) = (
            device.colors_as_booleans(&state.pool).await,
            device.ryg(&state.pool).await,
        ) {
            trigger_webhook::call(&state.http_client, &state.config.host, &device, &colors, &ryg).await;
        }
    }

    if device.identifier.is_some() {
        if let Some(ref token) = state.config.particle_access_token {
            trigger_particle::call(&state.http_client, token, &device).await;
        }
    }

    StatusCode::OK
}
