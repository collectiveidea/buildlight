mod common;

use axum::body::Body;
use axum::http::Request;
use http_body_util::BodyExt;
use sqlx::PgPool;
use tower::ServiceExt;

#[sqlx::test(migrations = "./migrations")]
async fn test_red_projects_json(pool: PgPool) {
    let red1_id = common::create_status(&pool, "travis", Some("user1"), Some("proj-a"), true, false).await;
    common::create_status(&pool, "travis", Some("user2"), Some("proj-b"), true, false).await;
    common::create_status(&pool, "travis", Some("user1"), Some("proj-c"), false, false).await;
    common::create_status(&pool, "travis", Some("user2"), Some("proj-d"), false, false).await;

    common::create_device(
        &pool, "Test", None, &["user1"], &[], Some("abc123"), None,
    ).await;

    let app = common::test_app(pool);

    let response = app
        .oneshot(
            Request::builder()
                .uri("/api/device/abc123/red.json")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
    let projects = json.as_array().unwrap();

    // Only user1's red project should be in the list
    assert_eq!(projects.len(), 1);

    // Suppress unused variable warning
    let _ = red1_id;
}

#[sqlx::test(migrations = "./migrations")]
async fn test_red_projects_html(pool: PgPool) {
    common::create_status(&pool, "travis", Some("user1"), Some("proj-a"), true, false).await;
    common::create_device(
        &pool, "Test", None, &["user1"], &[], Some("abc123"), None,
    ).await;

    let app = common::test_app(pool);

    let response = app
        .oneshot(
            Request::builder()
                .uri("/api/device/abc123/red")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let html = String::from_utf8(body.to_vec()).unwrap();

    assert!(html.contains("proj-a"));
}
