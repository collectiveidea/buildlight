mod common;

use axum::body::Body;
use axum::http::{Request, StatusCode};
use http_body_util::BodyExt;
use sqlx::PgPool;
use tower::ServiceExt;

fn circle_fixture() -> &'static str {
    include_str!("fixtures/circle.json")
}

fn circle_pr_fixture() -> &'static str {
    include_str!("fixtures/circle_pr.json")
}

#[sqlx::test(migrations = "./migrations")]
async fn test_circle_webhook(pool: PgPool) {
    let app = common::test_app(pool);

    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/")
                .header("content-type", "application/json")
                .header("circleci-event-type", "workflow-completed")
                .body(Body::from(circle_fixture()))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);
}

#[sqlx::test(migrations = "./migrations")]
async fn test_circle_saves_data(pool: PgPool) {
    let app = common::test_app(pool.clone());

    app.oneshot(
        Request::builder()
            .method("POST")
            .uri("/")
            .header("content-type", "application/json")
            .header("circleci-event-type", "workflow-completed")
            .body(Body::from(circle_fixture()))
            .unwrap(),
    )
    .await
    .unwrap();

    let status = sqlx::query_as::<_, buildlight::models::status::Status>(
        "SELECT * FROM statuses ORDER BY created_at DESC LIMIT 1",
    )
    .fetch_one(&pool)
    .await
    .unwrap();

    assert_eq!(status.red, Some(false));
    assert_eq!(status.service, "circle");
    assert_eq!(status.project_id, None);
    assert_eq!(status.project_name.as_deref(), Some("buildlight"));
    assert_eq!(status.username.as_deref(), Some("collectiveidea"));
}

#[sqlx::test(migrations = "./migrations")]
async fn test_circle_ignores_pull_requests(pool: PgPool) {
    let app = common::test_app(pool.clone());

    app.oneshot(
        Request::builder()
            .method("POST")
            .uri("/")
            .header("content-type", "application/json")
            .header("circleci-event-type", "workflow-completed")
            .body(Body::from(circle_pr_fixture()))
            .unwrap(),
    )
    .await
    .unwrap();

    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM statuses")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(count.0, 0);
}
