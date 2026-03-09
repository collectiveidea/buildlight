mod common;

use buildlight::models::status::Status;
use buildlight::services::{parse_circle, parse_github, parse_travis};
use sqlx::PgPool;

// --- GitHub ---

#[sqlx::test(migrations = "./migrations")]
async fn test_github_workflow_differentiates(pool: PgPool) {
    // Create an existing status with a different workflow
    common::create_status_full(
        &pool, "github", None, Some("collectiveidea"), Some("buildlight"),
        Some("Other Workflow"), true, false,
    ).await;

    let fixture: serde_json::Value =
        serde_json::from_str(include_str!("fixtures/github.json")).unwrap();
    let payload = parse_github::GitHubPayload {
        status: fixture["status"].as_str().unwrap().to_string(),
        repository: fixture["repository"].as_str().unwrap().to_string(),
        workflow: fixture["workflow"].as_str().map(String::from),
    };

    parse_github::call(&pool, &payload).await.unwrap();

    // The other_status should still be red
    let other = sqlx::query_as::<_, Status>(
        "SELECT * FROM statuses WHERE service = 'github' AND workflow = 'Other Workflow'",
    )
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(other.red, Some(true));

    // There should be two github statuses for this project
    let count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM statuses WHERE service = 'github' AND username = 'collectiveidea' AND project_name = 'buildlight'",
    )
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(count.0, 2);
}

#[test]
fn test_github_set_colors_success() {
    let (red, yellow) = parse_github::set_colors("success");
    assert_eq!(red, Some(false));
    assert_eq!(yellow, Some(false));
}

#[test]
fn test_github_set_colors_failure() {
    let (red, yellow) = parse_github::set_colors("failure");
    assert_eq!(red, Some(true));
    assert_eq!(yellow, Some(false));
}

#[test]
fn test_github_set_colors_empty() {
    let (red, yellow) = parse_github::set_colors("");
    assert_eq!(red, None);
    assert_eq!(yellow, Some(true));
}

// --- Travis ---

#[test]
fn test_travis_set_colors_passed() {
    let (red, yellow) = parse_travis::set_colors("Passed");
    assert_eq!(red, Some(false));
    assert_eq!(yellow, Some(false));
}

#[test]
fn test_travis_set_colors_fixed() {
    let (red, yellow) = parse_travis::set_colors("Fixed");
    assert_eq!(red, Some(false));
    assert_eq!(yellow, Some(false));
}

#[test]
fn test_travis_set_colors_still_failing() {
    let (red, yellow) = parse_travis::set_colors("Still Failing");
    assert_eq!(red, Some(true));
    assert_eq!(yellow, Some(false));
}

#[test]
fn test_travis_set_colors_pending() {
    let (red, yellow) = parse_travis::set_colors("Pending");
    assert_eq!(red, None);
    assert_eq!(yellow, Some(true));
}

// --- CircleCI ---

#[test]
fn test_circle_set_colors_success() {
    let (red, yellow) = parse_circle::set_colors("success");
    assert_eq!(red, Some(false));
    assert_eq!(yellow, Some(false));
}

#[test]
fn test_circle_set_colors_failed() {
    let (red, yellow) = parse_circle::set_colors("failed");
    assert_eq!(red, Some(true));
    assert_eq!(yellow, Some(false));
}
