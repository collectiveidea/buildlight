mod common;

use buildlight::models::status::Status;
use sqlx::PgPool;

#[sqlx::test(migrations = "./migrations")]
async fn test_colors_red_count(pool: PgPool) {
    common::create_status(&pool, "travis", None, None, true, false).await;
    let colors = Status::colors(&pool, None).await.unwrap();
    assert_eq!(colors.red, serde_json::json!(1));
}

#[sqlx::test(migrations = "./migrations")]
async fn test_colors_as_booleans_red(pool: PgPool) {
    common::create_status(&pool, "travis", None, None, true, false).await;
    let colors = Status::colors_as_booleans(&pool, None).await.unwrap();
    assert!(colors.red);
}

#[sqlx::test(migrations = "./migrations")]
async fn test_colors_red_and_yellow(pool: PgPool) {
    common::create_status(&pool, "travis", None, None, true, false).await;
    common::create_status(&pool, "travis", None, None, false, true).await;
    common::create_status(&pool, "travis", None, None, false, true).await;
    let colors = Status::colors(&pool, None).await.unwrap();
    assert!(colors.yellow);
    assert!(colors.red.is_number());
}

#[sqlx::test(migrations = "./migrations")]
async fn test_colors_another_project_red(pool: PgPool) {
    common::create_status(&pool, "travis", None, None, true, false).await;
    common::create_status(&pool, "travis", None, None, false, false).await;
    let colors = Status::colors(&pool, None).await.unwrap();
    assert!(colors.red.is_number());
}

#[sqlx::test(migrations = "./migrations")]
async fn test_colors_with_username(pool: PgPool) {
    common::create_status(&pool, "travis", Some("danielmorrison"), None, true, true).await;
    common::create_status(&pool, "travis", Some("collectiveidea"), None, true, false).await;
    let colors = Status::colors(&pool, Some(&["collectiveidea".into()])).await.unwrap();
    assert!(colors.red.is_number());
}

#[sqlx::test(migrations = "./migrations")]
async fn test_colors_with_username_red_and_yellow(pool: PgPool) {
    common::create_status(&pool, "travis", Some("danielmorrison"), None, true, true).await;
    common::create_status(&pool, "travis", Some("collectiveidea"), None, true, false).await;
    common::create_status(&pool, "travis", Some("collectiveidea"), None, false, true).await;
    common::create_status(&pool, "travis", Some("collectiveidea"), None, false, true).await;
    let colors = Status::colors(&pool, Some(&["collectiveidea".into()])).await.unwrap();
    assert!(colors.yellow);
    assert!(colors.red.is_number());
}

#[sqlx::test(migrations = "./migrations")]
async fn test_colors_with_username_another_project_red(pool: PgPool) {
    common::create_status(&pool, "travis", Some("danielmorrison"), None, true, true).await;
    common::create_status(&pool, "travis", Some("collectiveidea"), None, true, false).await;
    common::create_status(&pool, "travis", Some("collectiveidea"), None, false, false).await;
    let colors = Status::colors(&pool, Some(&["collectiveidea".into()])).await.unwrap();
    assert!(colors.red.is_number());
}

#[sqlx::test(migrations = "./migrations")]
async fn test_colors_with_multiple_usernames(pool: PgPool) {
    common::create_status(&pool, "travis", Some("collectiveidea"), None, true, false).await;
    common::create_status(&pool, "travis", Some("danielmorrison"), None, false, true).await;
    let colors = Status::colors(
        &pool,
        Some(&["collectiveidea".into(), "danielmorrison".into()]),
    )
    .await
    .unwrap();
    assert!(colors.red.is_number());
    assert!(colors.yellow);
}

#[sqlx::test(migrations = "./migrations")]
async fn test_name(pool: PgPool) {
    let status = Status {
        id: 1,
        project_id: None,
        project_name: Some("foo".into()),
        created_at: None,
        updated_at: None,
        payload: None,
        red: Some(false),
        yellow: Some(false),
        username: Some("collectiveidea".into()),
        service: "github".into(),
        workflow: None,
    };
    assert_eq!(status.name(), "collectiveidea/foo");
}

#[sqlx::test(migrations = "./migrations")]
async fn test_devices(pool: PgPool) {
    let _d1 = common::create_device(
        &pool, "D1", None, &["collectiveidea"], &["deadmanssnitch/foo"], None, None,
    ).await;
    let _d2 = common::create_device(
        &pool, "D2", None, &["collectiveidea", "deadmanssnitch"], &[], None, None,
    ).await;
    let _d3 = common::create_device(
        &pool, "D3", None, &["deadmanssnitch"], &["collectiveidea/foo"], None, None,
    ).await;
    let _d4 = common::create_device(
        &pool, "D4", None, &[], &["collectiveidea/foo"], None, None,
    ).await;
    let _d5 = common::create_device(
        &pool, "D5", None, &["deadmanssnitch"], &[], None, None,
    ).await;

    common::create_status(&pool, "travis", Some("collectiveidea"), Some("foo"), false, false).await;

    let status = sqlx::query_as::<_, Status>("SELECT * FROM statuses ORDER BY id DESC LIMIT 1")
        .fetch_one(&pool)
        .await
        .unwrap();

    let devices = status.devices(&pool).await.unwrap();
    let device_names: Vec<&str> = devices.iter().map(|d| d.name.as_str()).collect();

    assert!(device_names.contains(&"D1"));
    assert!(device_names.contains(&"D2"));
    assert!(device_names.contains(&"D3"));
    assert!(device_names.contains(&"D4"));
    assert!(!device_names.contains(&"D5"));
}
