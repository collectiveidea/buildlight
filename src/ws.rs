use axum::extract::ws::{Message, WebSocket};
use axum::extract::{Query, State, WebSocketUpgrade};
use axum::response::IntoResponse;
use futures::SinkExt;
use futures::StreamExt;
use serde::Deserialize;

use crate::app::AppState;

#[derive(Clone, Debug)]
pub struct BroadcastMsg {
    pub channel: String,
    pub id: String,
    pub payload: serde_json::Value,
}

#[derive(Deserialize)]
pub struct WsParams {
    pub channel: String,
    pub id: String,
}

pub async fn ws_handler(
    ws: WebSocketUpgrade,
    Query(params): Query<WsParams>,
    State(state): State<AppState>,
) -> impl IntoResponse {
    ws.on_upgrade(move |socket| handle_socket(socket, params, state))
}

async fn handle_socket(socket: WebSocket, params: WsParams, state: AppState) {
    let (mut sender, mut receiver) = socket.split();
    let mut rx = state.broadcaster.subscribe();

    let channel = params.channel;
    let id = params.id;

    // Send initial state
    let initial = match channel.as_str() {
        "colors" => {
            let ids: Option<Vec<String>> = if id == "*" { None } else { Some(id.split(',').map(String::from).collect()) };
            crate::models::status::Status::colors(&state.pool, ids.as_deref()).await.ok()
        }
        "device" => {
            let colors = crate::models::device::Device::colors_by_slug(&state.pool, &id).await.ok();
            colors
        }
        _ => None,
    };

    if let Some(colors) = initial {
        let msg = serde_json::json!({"colors": colors});
        if sender.send(Message::Text(msg.to_string().into())).await.is_err() {
            return;
        }
    }

    // Forward broadcast messages matching this subscription
    let channel_clone = channel.clone();
    let id_clone = id.clone();
    let send_task = tokio::spawn(async move {
        while let Ok(msg) = rx.recv().await {
            if msg.channel == channel_clone && (msg.id == id_clone || id_clone == "*" || msg.id == "*") {
                let payload = serde_json::json!({"colors": msg.payload});
                if sender.send(Message::Text(payload.to_string().into())).await.is_err() {
                    break;
                }
            }
        }
    });

    // Drain incoming messages (we don't expect any, but keep the connection alive)
    let recv_task = tokio::spawn(async move {
        while let Some(Ok(msg)) = receiver.next().await {
            if matches!(msg, Message::Close(_)) {
                break;
            }
        }
    });

    tokio::select! {
        _ = send_task => {},
        _ = recv_task => {},
    }
}
