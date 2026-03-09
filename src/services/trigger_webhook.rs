use crate::models::device::Device;
use crate::models::status::ColorsAsBooleans;

pub async fn call(client: &reqwest::Client, host: &str, device: &Device, colors: &ColorsAsBooleans, ryg: &str) {
    let Some(ref webhook_url) = device.webhook_url else {
        return;
    };

    let body = serde_json::json!({
        "colors": colors,
    });

    let device_url = format!("http://{host}/api/devices/{}", device.id);

    let result = client
        .post(webhook_url)
        .header("Content-Type", "application/json")
        .header("x-ryg", ryg)
        .header("x-device-url", device_url)
        .body(body.to_string())
        .send()
        .await;

    if let Err(e) = result {
        tracing::error!("Failed to send webhook to {webhook_url}: {e}");
    }
}
