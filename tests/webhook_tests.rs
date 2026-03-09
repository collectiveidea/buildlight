mod common;

use axum::body::Body;
use axum::http::{Request, StatusCode};
use sqlx::PgPool;
use tower::ServiceExt;

fn travis_fixture() -> String {
    include_str!("fixtures/travis.json").to_string()
}

fn github_fixture() -> &'static str {
    include_str!("fixtures/github.json")
}

#[sqlx::test(migrations = "./migrations")]
async fn test_unknown_data_returns_bad_request(pool: PgPool) {
    let app = common::test_app(pool.clone());

    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM statuses")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(count.0, 0);

    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/")
                .header("content-type", "application/json")
                .body(Body::from(r#"{"foo": "bar"}"#))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::BAD_REQUEST);

    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM statuses")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(count.0, 0);
}

#[sqlx::test(migrations = "./migrations")]
async fn test_travis_webhook(pool: PgPool) {
    let app = common::test_app(pool.clone());

    let body = serde_json::json!({"payload": travis_fixture()});
    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/")
                .header("content-type", "application/json")
                .body(Body::from(body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);
}

#[sqlx::test(migrations = "./migrations")]
async fn test_travis_saves_data(pool: PgPool) {
    let app = common::test_app(pool.clone());

    let body = serde_json::json!({"payload": travis_fixture()});
    app.oneshot(
        Request::builder()
            .method("POST")
            .uri("/")
            .header("content-type", "application/json")
            .body(Body::from(body.to_string()))
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
    assert_eq!(status.service, "travis");
    assert_eq!(status.project_id.as_deref(), Some("347744"));
    assert_eq!(status.project_name.as_deref(), Some("buildlight"));
    assert_eq!(status.username.as_deref(), Some("collectiveidea"));
}

#[sqlx::test(migrations = "./migrations")]
async fn test_travis_ignores_pull_requests(pool: PgPool) {
    let app = common::test_app(pool.clone());

    let fixture = travis_fixture().replace(r#""type":"push""#, r#""type":"pull_request""#);
    let body = serde_json::json!({"payload": fixture});
    app.oneshot(
        Request::builder()
            .method("POST")
            .uri("/")
            .header("content-type", "application/json")
            .body(Body::from(body.to_string()))
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

#[sqlx::test(migrations = "./migrations")]
async fn test_github_webhook(pool: PgPool) {
    let app = common::test_app(pool.clone());
    let payload: serde_json::Value = serde_json::from_str(github_fixture()).unwrap();

    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/")
                .header("content-type", "application/json")
                .body(Body::from(payload.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);
}

#[sqlx::test(migrations = "./migrations")]
async fn test_github_saves_data(pool: PgPool) {
    let app = common::test_app(pool.clone());
    let payload: serde_json::Value = serde_json::from_str(github_fixture()).unwrap();

    app.oneshot(
        Request::builder()
            .method("POST")
            .uri("/")
            .header("content-type", "application/json")
            .body(Body::from(payload.to_string()))
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
    assert_eq!(status.service, "github");
    assert_eq!(status.project_id, None);
    assert_eq!(status.project_name.as_deref(), Some("buildlight"));
    assert_eq!(status.username.as_deref(), Some("collectiveidea"));
}
