mod common;

use buildlight::models::device::Device;
use sqlx::PgPool;

#[sqlx::test(migrations = "./migrations")]
async fn test_statuses_by_project(pool: PgPool) {
    common::create_status(&pool, "travis", Some("collectiveidea"), Some("foo"), false, false).await;
    common::create_status(&pool, "travis", Some("collectiveidea"), Some("bar"), false, false).await;
    common::create_status(&pool, "travis", Some("deadmanssnitch"), Some("foo"), false, false).await;
    common::create_status(&pool, "travis", Some("deadmanssnitch"), Some("bar"), false, false).await;
    common::create_status(&pool, "travis", Some("inchworm"), Some("foo"), false, false).await;

    let device_id = common::create_device(
        &pool, "Test Device", None, &[], &["collectiveidea/bar", "deadmanssnitch/foo"], None, None,
    ).await;

    let device = sqlx::query_as::<_, Device>("SELECT * FROM devices WHERE id = $1")
        .bind(device_id)
        .fetch_one(&pool)
        .await
        .unwrap();

    let statuses = device.statuses(&pool).await.unwrap();
    assert_eq!(statuses.len(), 2);

    let names: Vec<String> = statuses.iter().map(|s| s.name()).collect();
    assert!(names.contains(&"collectiveidea/bar".to_string()));
    assert!(names.contains(&"deadmanssnitch/foo".to_string()));
}

#[sqlx::test(migrations = "./migrations")]
async fn test_statuses_by_username(pool: PgPool) {
    common::create_status(&pool, "travis", Some("collectiveidea"), Some("foo"), false, false).await;
    common::create_status(&pool, "travis", Some("collectiveidea"), Some("bar"), false, false).await;
    common::create_status(&pool, "travis", Some("deadmanssnitch"), Some("foo"), false, false).await;
    common::create_status(&pool, "travis", Some("deadmanssnitch"), Some("bar"), false, false).await;
    common::create_status(&pool, "travis", Some("inchworm"), Some("foo"), false, false).await;

    let device_id = common::create_device(
        &pool, "Test Device", None, &["collectiveidea", "inchworm"], &[], None, None,
    ).await;

    let device = sqlx::query_as::<_, Device>("SELECT * FROM devices WHERE id = $1")
        .bind(device_id)
        .fetch_one(&pool)
        .await
        .unwrap();

    let statuses = device.statuses(&pool).await.unwrap();
    assert_eq!(statuses.len(), 3);
}

#[sqlx::test(migrations = "./migrations")]
async fn test_statuses_by_username_and_project(pool: PgPool) {
    common::create_status(&pool, "travis", Some("collectiveidea"), Some("foo"), false, false).await;
    common::create_status(&pool, "travis", Some("collectiveidea"), Some("bar"), false, false).await;
    common::create_status(&pool, "travis", Some("deadmanssnitch"), Some("foo"), false, false).await;
    common::create_status(&pool, "travis", Some("deadmanssnitch"), Some("bar"), false, false).await;
    common::create_status(&pool, "travis", Some("inchworm"), Some("foo"), false, false).await;

    let device_id = common::create_device(
        &pool, "Test Device", None, &["collectiveidea"], &["deadmanssnitch/bar"], None, None,
    ).await;

    let device = sqlx::query_as::<_, Device>("SELECT * FROM devices WHERE id = $1")
        .bind(device_id)
        .fetch_one(&pool)
        .await
        .unwrap();

    let statuses = device.statuses(&pool).await.unwrap();
    assert_eq!(statuses.len(), 3);
}

#[sqlx::test(migrations = "./migrations")]
async fn test_current_status(pool: PgPool) {
    common::create_status(&pool, "travis", Some("collectiveidea"), Some("foo"), false, false).await;
    common::create_status(&pool, "travis", Some("collectiveidea"), Some("bar"), false, true).await;
    common::create_status(&pool, "travis", Some("deadmanssnitch"), Some("foo"), false, false).await;
    common::create_status(&pool, "travis", Some("deadmanssnitch"), Some("bar"), true, true).await;

    let device_id = common::create_device(
        &pool, "Test Device", None, &["collectiveidea"], &["deadmanssnitch/foo"], None, None,
    ).await;

    let mut device = sqlx::query_as::<_, Device>("SELECT * FROM devices WHERE id = $1")
        .bind(device_id)
        .fetch_one(&pool)
        .await
        .unwrap();

    device.update_status(&pool).await.unwrap();
    assert_eq!(device.status.as_deref(), Some("passing-building"));

    // Add a failing status
    common::create_status(&pool, "travis", Some("collectiveidea"), Some("baz"), true, false).await;

    let mut device = sqlx::query_as::<_, Device>("SELECT * FROM devices WHERE id = $1")
        .bind(device_id)
        .fetch_one(&pool)
        .await
        .unwrap();

    device.update_status(&pool).await.unwrap();
    assert_eq!(device.status.as_deref(), Some("failing-building"));
}
