use serde::Deserialize;
use sqlx::PgPool;

use crate::models::status::Status;

#[derive(Debug, Deserialize)]
pub struct GitHubPayload {
    pub status: String,
    pub repository: String,
    pub workflow: Option<String>,
}

pub async fn call(pool: &PgPool, payload: &GitHubPayload) -> Result<Status, sqlx::Error> {
    let parts: Vec<&str> = payload.repository.splitn(2, '/').collect();
    let (username, project_name) = if parts.len() == 2 {
        (Some(parts[0]), Some(parts[1]))
    } else {
        (None, None)
    };

    let (red, yellow) = set_colors(payload.status.as_str());

    Status::upsert(
        pool,
        "github",
        None,
        username,
        project_name,
        payload.workflow.as_deref(),
        red,
        yellow,
    )
    .await
}

/// Returns (red, yellow) overrides. None means "keep existing value".
pub fn set_colors(code: &str) -> (Option<bool>, Option<bool>) {
    match code {
        "" => (None, Some(true)),
        "success" => (Some(false), Some(false)),
        "failure" => (Some(true), Some(false)),
        other => panic!("Unknown status: {other}"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_set_colors_success() {
        let (red, yellow) = set_colors("success");
        assert_eq!(red, Some(false));
        assert_eq!(yellow, Some(false));
    }

    #[test]
    fn test_set_colors_failure() {
        let (red, yellow) = set_colors("failure");
        assert_eq!(red, Some(true));
        assert_eq!(yellow, Some(false));
    }

    #[test]
    fn test_set_colors_empty() {
        let (red, yellow) = set_colors("");
        assert_eq!(red, None); // keeps existing red value
        assert_eq!(yellow, Some(true));
    }
}
