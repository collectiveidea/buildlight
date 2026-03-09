mod common;

use axum::body::Body;
use axum::http::Request;
use http_body_util::BodyExt;
use sqlx::PgPool;
use tower::ServiceExt;

#[sqlx::test(migrations = "./migrations")]
async fn test_index_red(pool: PgPool) {
    common::create_status(&pool, "travis", None, None, true, false).await;
    let app = common::test_app(pool);

    let response = app
        .oneshot(
            Request::builder()
                .uri("/.json")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert!(json["red"].is_number());
}

#[sqlx::test(migrations = "./migrations")]
async fn test_index_red_and_yellow(pool: PgPool) {
    common::create_status(&pool, "travis", None, None, true, false).await;
    common::create_status(&pool, "travis", None, None, false, true).await;
    common::create_status(&pool, "travis", None, None, false, true).await;
    let app = common::test_app(pool);

    let response = app
        .oneshot(
            Request::builder()
                .uri("/.json")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert_eq!(json["yellow"], true);
    assert!(json["red"].is_number());
}

#[sqlx::test(migrations = "./migrations")]
async fn test_index_another_project_red(pool: PgPool) {
    common::create_status(&pool, "travis", None, None, true, false).await;
    common::create_status(&pool, "travis", None, None, false, false).await;
    let app = common::test_app(pool);

    let response = app
        .oneshot(
            Request::builder()
                .uri("/.json")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert!(json["red"].is_number());
}

#[sqlx::test(migrations = "./migrations")]
async fn test_show_single_user(pool: PgPool) {
    common::create_status(&pool, "travis", Some("collectiveidea"), None, false, false).await;
    common::create_status(&pool, "travis", Some("danielmorrison"), None, true, false).await;
    let app = common::test_app(pool);

    let response = app
        .oneshot(
            Request::builder()
                .uri("/collectiveidea.json")
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
async fn test_show_multiple_users(pool: PgPool) {
    common::create_status(&pool, "travis", Some("collectiveidea"), None, false, true).await;
    common::create_status(&pool, "travis", Some("danielmorrison"), None, true, false).await;
    let app = common::test_app(pool);

    let response = app
        .oneshot(
            Request::builder()
                .uri("/collectiveidea,danielmorrison.json")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert!(json["red"].is_number());
    assert_eq!(json["yellow"], true);
}
