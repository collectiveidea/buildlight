use serde::Deserialize;
use sqlx::PgPool;

use crate::models::status::Status;

#[derive(Debug, Deserialize)]
pub struct CirclePayload {
    #[serde(rename = "type")]
    pub event_type: Option<String>,
    pub pipeline: Option<CirclePipeline>,
    pub project: Option<CircleProject>,
    pub organization: Option<CircleOrganization>,
    pub workflow: Option<CircleWorkflow>,
}

#[derive(Debug, Deserialize)]
pub struct CirclePipeline {
    pub vcs: Option<CircleVcs>,
}

#[derive(Debug, Deserialize)]
pub struct CircleVcs {
    pub branch: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct CircleProject {
    pub name: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct CircleOrganization {
    pub name: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct CircleWorkflow {
    pub status: Option<String>,
}

pub async fn call(pool: &PgPool, payload: &CirclePayload) -> Result<Option<Status>, sqlx::Error> {
    // Only process workflow-completed events
    if payload.event_type.as_deref() != Some("workflow-completed") {
        return Ok(None);
    }

    // Ignore non-main branches (PR builds)
    let branch = payload
        .pipeline
        .as_ref()
        .and_then(|p| p.vcs.as_ref())
        .and_then(|v| v.branch.as_deref());

    if !matches!(branch, Some("main" | "master")) {
        return Ok(None);
    }

    let username = payload.organization.as_ref().and_then(|o| o.name.as_deref());
    let project_name = payload.project.as_ref().and_then(|p| p.name.as_deref());
    let workflow_status = payload.workflow.as_ref().and_then(|w| w.status.as_deref());

    let (red, yellow) = set_colors(workflow_status.unwrap_or("unknown"));

    let status = Status::upsert(pool, "circle", None, username, project_name, None, red, yellow).await?;

    Ok(Some(status))
}

pub fn set_colors(code: &str) -> (Option<bool>, Option<bool>) {
    // CircleCI has no in-progress state via webhooks, so no yellow
    let red = code != "success";
    (Some(red), Some(false))
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
    fn test_set_colors_failed() {
        let (red, yellow) = set_colors("failed");
        assert_eq!(red, Some(true));
        assert_eq!(yellow, Some(false));
    }
}
