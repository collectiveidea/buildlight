use serde::Deserialize;
use sqlx::PgPool;

use crate::models::status::Status;

#[derive(Debug, Deserialize)]
pub struct TravisPayload {
    pub id: Option<serde_json::Value>,
    pub repository: TravisRepository,
    pub status_message: String,
    #[serde(rename = "type")]
    pub event_type: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct TravisRepository {
    pub id: serde_json::Value,
    pub name: String,
    pub owner_name: String,
}

pub async fn call(pool: &PgPool, raw_payload: &str) -> Result<Option<Status>, sqlx::Error> {
    let payload: TravisPayload = match serde_json::from_str(raw_payload) {
        Ok(p) => p,
        Err(_) => return Ok(None),
    };

    // Ignore pull requests
    if payload.event_type.as_deref() == Some("pull_request") {
        return Ok(None);
    }

    let (red, yellow) = set_colors(&payload.status_message);
    let project_id = payload.repository.id.to_string();

    let status = Status::upsert(
        pool,
        "travis",
        Some(&project_id),
        Some(&payload.repository.owner_name),
        Some(&payload.repository.name),
        None,
        red,
        yellow,
    )
    .await?;

    Ok(Some(status))
}

pub fn set_colors(code: &str) -> (Option<bool>, Option<bool>) {
    match code {
        "Pending" => (None, Some(true)),
        "Passed" | "Fixed" => (Some(false), Some(false)),
        _ => (Some(true), Some(false)), // "Still Failing", "Failed", "Broken", "Errored", etc.
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_set_colors_passed() {
        let (red, yellow) = set_colors("Passed");
        assert_eq!(red, Some(false));
        assert_eq!(yellow, Some(false));
    }

    #[test]
    fn test_set_colors_fixed() {
        let (red, yellow) = set_colors("Fixed");
        assert_eq!(red, Some(false));
        assert_eq!(yellow, Some(false));
    }

    #[test]
    fn test_set_colors_still_failing() {
        let (red, yellow) = set_colors("Still Failing");
        assert_eq!(red, Some(true));
        assert_eq!(yellow, Some(false));
    }

    #[test]
    fn test_set_colors_pending() {
        let (red, yellow) = set_colors("Pending");
        assert_eq!(red, None);
        assert_eq!(yellow, Some(true));
    }
}
