mod common;

use axum::body::Body;
use axum::http::{Request, StatusCode};
use http_body_util::BodyExt;
use sqlx::PgPool;
use tower::ServiceExt;

#[sqlx::test(migrations = "./migrations")]
async fn test_api_device_show(pool: PgPool) {
    common::create_status(&pool, "travis", Some("test"), None, false, true).await;
    let device_id = common::create_device(
        &pool, "Test", None, &["test"], &[], None, None,
    ).await;

    let app = common::test_app(pool);

    let response = app
        .oneshot(
            Request::builder()
                .uri(format!("/api/devices/{device_id}"))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);
    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();

    assert_eq!(json["colors"]["red"], false);
    assert_eq!(json["colors"]["yellow"], true);
    assert_eq!(json["colors"]["green"], true);
    assert_eq!(json["ryg"], "rYG");
}

#[sqlx::test(migrations = "./migrations")]
async fn test_api_device_trigger_with_device(pool: PgPool) {
    common::create_device(
        &pool, "Test", None, &[], &[], Some("abc123"), None,
    ).await;

    let app = common::test_app(pool);

    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/device/trigger")
                .header("content-type", "application/json")
                .body(Body::from(
                    r#"{"name":"ready","data":"true","coreid":"abc123","published_at":"2016-06-14T22:06:10.976Z"}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);
}

#[sqlx::test(migrations = "./migrations")]
async fn test_api_device_trigger_without_device(pool: PgPool) {
    let app = common::test_app(pool);

    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/device/trigger")
                .header("content-type", "application/json")
                .body(Body::from(
                    r#"{"name":"ready","data":"true","coreid":"FAKE","published_at":"2016-06-14T22:06:10.976Z"}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);
}
