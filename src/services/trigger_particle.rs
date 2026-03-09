use crate::models::device::Device;

pub async fn call(client: &reqwest::Client, access_token: &str, device: &Device) {
    let status = device.status.as_deref().unwrap_or("passing");

    let result = client
        .post("https://api.particle.io/v1/events")
        .bearer_auth(access_token)
        .form(&[
            ("name", "build_state"),
            ("data", status),
            ("ttl", "3600"),
            ("private", "false"),
        ])
        .send()
        .await;

    if let Err(e) = result {
        tracing::error!("Failed to publish to Particle: {e}");
    }
}
