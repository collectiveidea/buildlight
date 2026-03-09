mod common;

use axum::body::Body;
use axum::http::Request;
use http_body_util::BodyExt;
use sqlx::PgPool;
use tower::ServiceExt;

#[sqlx::test(migrations = "./migrations")]
async fn test_show_device_by_id(pool: PgPool) {
    common::create_status(&pool, "travis", Some("collectiveidea"), None, false, false).await;
    common::create_status(&pool, "travis", Some("danielmorrison"), None, true, false).await;
    let device_id = common::create_device(
        &pool, "Test", Some("test-slug"), &["collectiveidea"], &[], None, None,
    ).await;

    let app = common::test_app(pool);

    let response = app
        .oneshot(
            Request::builder()
                .uri(format!("/devices/{device_id}.json"))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert_eq!(json["red"], false);
}

#[sqlx::test(migrations = "./migrations")]
async fn test_show_device_by_slug(pool: PgPool) {
    common::create_status(&pool, "travis", Some("collectiveidea"), None, false, false).await;
    common::create_status(&pool, "travis", Some("danielmorrison"), None, true, false).await;
    let _device_id = common::create_device(
        &pool, "Test", Some("test-slug"), &["collectiveidea"], &[], None, None,
    ).await;

    let app = common::test_app(pool);

    let response = app
        .oneshot(
            Request::builder()
                .uri("/devices/test-slug.json")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert_eq!(json["red"], false);
}
