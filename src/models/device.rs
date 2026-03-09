use chrono::NaiveDateTime;
use sqlx::PgPool;
use uuid::Uuid;

use super::status::{Colors, ColorsAsBooleans, Status};

#[derive(Debug, Clone, sqlx::FromRow)]
pub struct Device {
    pub id: Uuid,
    pub usernames: Vec<String>,
    pub projects: Vec<String>,
    pub created_at: NaiveDateTime,
    pub updated_at: NaiveDateTime,
    pub identifier: Option<String>,
    pub name: String,
    pub webhook_url: Option<String>,
    pub slug: Option<String>,
    pub status: Option<String>,
    pub status_changed_at: Option<NaiveDateTime>,
}

impl Device {
    pub async fn find_by_slug_or_id(pool: &PgPool, slug_or_id: &str) -> Result<Self, sqlx::Error> {
        // Try UUID first, then slug
        if let Ok(uuid) = Uuid::parse_str(slug_or_id) {
            let device = sqlx::query_as::<_, Device>(
                "SELECT * FROM devices WHERE id = $1 OR slug = $2 LIMIT 1",
            )
            .bind(uuid)
            .bind(slug_or_id)
            .fetch_one(pool)
            .await?;
            return Ok(device);
        }

        sqlx::query_as::<_, Device>("SELECT * FROM devices WHERE slug = $1")
            .bind(slug_or_id)
            .fetch_one(pool)
            .await
    }

    pub async fn find_by_identifier(pool: &PgPool, identifier: &str) -> Result<Option<Self>, sqlx::Error> {
        sqlx::query_as::<_, Device>("SELECT * FROM devices WHERE identifier = $1")
            .bind(identifier)
            .fetch_optional(pool)
            .await
    }

    /// Get all statuses that this device is watching.
    pub async fn statuses(&self, pool: &PgPool) -> Result<Vec<Status>, sqlx::Error> {
        sqlx::query_as::<_, Status>(
            "SELECT * FROM statuses WHERE username = ANY($1) \
             OR (username || '/' || project_name) = ANY($2)",
        )
        .bind(&self.usernames)
        .bind(&self.projects)
        .fetch_all(pool)
        .await
    }

    /// Get colors for this device based on its watched statuses.
    pub async fn colors(&self, pool: &PgPool) -> Result<Colors, sqlx::Error> {
        let red_count: i64 = sqlx::query_scalar(
            "SELECT COUNT(*) FROM statuses \
             WHERE red = true AND (username = ANY($1) OR (username || '/' || project_name) = ANY($2))",
        )
        .bind(&self.usernames)
        .bind(&self.projects)
        .fetch_one(pool)
        .await?;

        let yellow: bool = sqlx::query_scalar(
            "SELECT EXISTS(SELECT 1 FROM statuses \
             WHERE yellow = true AND (username = ANY($1) OR (username || '/' || project_name) = ANY($2)))",
        )
        .bind(&self.usernames)
        .bind(&self.projects)
        .fetch_one(pool)
        .await?;

        let red_value = if red_count > 0 {
            serde_json::Value::Number(red_count.into())
        } else {
            serde_json::Value::Bool(false)
        };

        Ok(Colors {
            green: red_count == 0,
            red: red_value,
            yellow,
        })
    }

    pub async fn colors_as_booleans(&self, pool: &PgPool) -> Result<ColorsAsBooleans, sqlx::Error> {
        let colors = self.colors(pool).await?;
        Ok(ColorsAsBooleans {
            red: colors.red.as_bool().map_or(true, |b| b),
            yellow: colors.yellow,
            green: colors.green,
        })
    }

    pub async fn ryg(&self, pool: &PgPool) -> Result<String, sqlx::Error> {
        let colors = self.colors(pool).await?;
        let r = if colors.red != serde_json::Value::Bool(false) { 'R' } else { 'r' };
        let y = if colors.yellow { 'Y' } else { 'y' };
        let g = if colors.green { 'G' } else { 'g' };
        Ok(format!("{r}{y}{g}"))
    }

    /// Compute and return the current status string (e.g. "passing", "failing-building").
    pub async fn current_status(&self, pool: &PgPool) -> Result<String, sqlx::Error> {
        let has_red: bool = sqlx::query_scalar(
            "SELECT EXISTS(SELECT 1 FROM statuses \
             WHERE red = true AND (username = ANY($1) OR (username || '/' || project_name) = ANY($2)))",
        )
        .bind(&self.usernames)
        .bind(&self.projects)
        .fetch_one(pool)
        .await?;

        let has_yellow: bool = sqlx::query_scalar(
            "SELECT EXISTS(SELECT 1 FROM statuses \
             WHERE yellow = true AND (username = ANY($1) OR (username || '/' || project_name) = ANY($2)))",
        )
        .bind(&self.usernames)
        .bind(&self.projects)
        .fetch_one(pool)
        .await?;

        let mut parts = Vec::new();
        if !has_red {
            parts.push("passing");
        }
        if has_red {
            parts.push("failing");
        }
        if has_yellow {
            parts.push("building");
        }
        Ok(parts.join("-"))
    }

    /// Update the device status and persist if changed. Returns whether the status changed.
    pub async fn update_status(&mut self, pool: &PgPool) -> Result<bool, sqlx::Error> {
        let new_status = self.current_status(pool).await?;
        let changed = self.status.as_deref() != Some(&new_status);

        self.status = Some(new_status);

        if changed {
            self.status_changed_at = Some(chrono::Utc::now().naive_utc());
            sqlx::query("UPDATE devices SET status = $1, status_changed_at = $2, updated_at = NOW() WHERE id = $3")
                .bind(&self.status)
                .bind(self.status_changed_at)
                .bind(self.id)
                .execute(pool)
                .await?;
        }

        Ok(changed)
    }

    /// Helper to get colors by slug (for WebSocket initial state).
    pub async fn colors_by_slug(pool: &PgPool, slug: &str) -> Result<Colors, sqlx::Error> {
        let device = sqlx::query_as::<_, Device>("SELECT * FROM devices WHERE slug = $1")
            .bind(slug)
            .fetch_one(pool)
            .await?;
        device.colors(pool).await
    }
}
