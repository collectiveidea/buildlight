use axum::extract::State;
use axum::http::{HeaderMap, StatusCode};
use axum::Json;

use crate::app::AppState;
use crate::models::status::Status;
use crate::services::{parse_circle, parse_github, parse_travis, trigger_particle, trigger_webhook};

/// POST / - Receive webhooks from CI services.
pub async fn create(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<serde_json::Value>,
) -> StatusCode {
    // Travis sends the payload as a form-encoded "payload" string field.
    // Our Axum handler receives JSON, but Travis payloads come as a string.
    if let Some(payload_str) = body.get("payload").and_then(|v| v.as_str()) {
        match parse_travis::call(&state.pool, payload_str).await {
            Ok(Some(status)) => {
                broadcast_and_trigger(&state, &status).await;
                return StatusCode::OK;
            }
            Ok(None) => return StatusCode::OK,
            Err(e) => {
                tracing::error!("Travis parse error: {e}");
                return StatusCode::INTERNAL_SERVER_ERROR;
            }
        }
    }

    // GitHub Actions: has "repository" containing "/" but no "payload"
    if body.get("payload").is_none() {
        if let Some(repo) = body.get("repository").and_then(|v| v.as_str()) {
            if repo.contains('/') {
                let payload = parse_github::GitHubPayload {
                    status: body
                        .get("status")
                        .and_then(|v| v.as_str())
                        .unwrap_or("")
                        .to_string(),
                    repository: repo.to_string(),
                    workflow: body.get("workflow").and_then(|v| v.as_str()).map(String::from),
                };

                match parse_github::call(&state.pool, &payload).await {
                    Ok(status) => {
                        broadcast_and_trigger(&state, &status).await;
                        return StatusCode::OK;
                    }
                    Err(e) => {
                        tracing::error!("GitHub parse error: {e}");
                        return StatusCode::INTERNAL_SERVER_ERROR;
                    }
                }
            }
        }
    }

    // CircleCI: has Circleci-Event-Type header
    let is_circle = headers
        .get("circleci-event-type")
        .is_some();

    if is_circle {
        let payload: parse_circle::CirclePayload = match serde_json::from_value(body) {
            Ok(p) => p,
            Err(e) => {
                tracing::error!("CircleCI parse error: {e}");
                return StatusCode::BAD_REQUEST;
            }
        };

        match parse_circle::call(&state.pool, &payload).await {
            Ok(Some(status)) => {
                broadcast_and_trigger(&state, &status).await;
                return StatusCode::OK;
            }
            Ok(None) => return StatusCode::OK,
            Err(e) => {
                tracing::error!("CircleCI error: {e}");
                return StatusCode::INTERNAL_SERVER_ERROR;
            }
        }
    }

    StatusCode::BAD_REQUEST
}

async fn broadcast_and_trigger(state: &AppState, status: &Status) {
    // Broadcast to colors channels
    if let Ok(colors) = Status::colors(&state.pool, None).await {
        let _ = state.broadcaster.send(crate::ws::BroadcastMsg {
            channel: "colors".into(),
            id: "*".into(),
            payload: serde_json::to_value(&colors).unwrap_or_default(),
        });
    }

    if let Some(ref username) = status.username {
        if let Ok(colors) = Status::colors(&state.pool, Some(&[username.clone()])).await {
            let _ = state.broadcaster.send(crate::ws::BroadcastMsg {
                channel: "colors".into(),
                id: username.clone(),
                payload: serde_json::to_value(&colors).unwrap_or_default(),
            });
        }
    }

    // Update devices watching this status
    if let Ok(devices) = status.devices(&state.pool).await {
        for mut device in devices {
            let changed = device.update_status(&state.pool).await.unwrap_or(false);

            // Broadcast to device channel
            if let Some(ref slug) = device.slug {
                if let Ok(colors) = device.colors(&state.pool).await {
                    let _ = state.broadcaster.send(crate::ws::BroadcastMsg {
                        channel: "device".into(),
                        id: slug.clone(),
                        payload: serde_json::to_value(&colors).unwrap_or_default(),
                    });
                }
            }

            // Only trigger external actions on status change
            if changed {
                if device.webhook_url.is_some() {
                    if let (Ok(colors), Ok(ryg)) =
                        (device.colors_as_booleans(&state.pool).await, device.ryg(&state.pool).await)
                    {
                        trigger_webhook::call(&state.http_client, &state.config.host, &device, &colors, &ryg)
                            .await;
                    }
                }

                if device.identifier.is_some() {
                    if let Some(ref token) = state.config.particle_access_token {
                        trigger_particle::call(&state.http_client, token, &device).await;
                    }
                }
            }
        }
    }
}
