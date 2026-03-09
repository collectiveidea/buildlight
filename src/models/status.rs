use chrono::NaiveDateTime;
use serde::Serialize;
use sqlx::PgPool;

#[derive(Debug, Clone, sqlx::FromRow)]
pub struct Status {
    pub id: i64,
    pub project_id: Option<String>,
    pub project_name: Option<String>,
    pub created_at: Option<NaiveDateTime>,
    pub updated_at: Option<NaiveDateTime>,
    pub payload: Option<String>,
    pub red: Option<bool>,
    pub yellow: Option<bool>,
    pub username: Option<String>,
    pub service: String,
    pub workflow: Option<String>,
}

/// Colors representation where `red` is either a count (positive i64) or false.
#[derive(Debug, Clone, Serialize)]
pub struct Colors {
    pub red: serde_json::Value,
    pub yellow: bool,
    pub green: bool,
}

/// Colors with all boolean values.
#[derive(Debug, Clone, Serialize)]
pub struct ColorsAsBooleans {
    pub red: bool,
    pub yellow: bool,
    pub green: bool,
}

impl Status {
    pub fn name(&self) -> String {
        format!(
            "{}/{}",
            self.username.as_deref().unwrap_or(""),
            self.project_name.as_deref().unwrap_or("")
        )
    }

    /// Query the aggregate colors for all statuses, optionally filtered by username(s).
    pub async fn colors(pool: &PgPool, usernames: Option<&[String]>) -> Result<Colors, sqlx::Error> {
        let red_count: i64 = match usernames {
            Some(names) if !names.is_empty() => {
                sqlx::query_scalar("SELECT COUNT(*) FROM statuses WHERE red = true AND username = ANY($1)")
                    .bind(names)
                    .fetch_one(pool)
                    .await?
            }
            _ => {
                sqlx::query_scalar("SELECT COUNT(*) FROM statuses WHERE red = true")
                    .fetch_one(pool)
                    .await?
            }
        };

        let yellow: bool = match usernames {
            Some(names) if !names.is_empty() => {
                sqlx::query_scalar(
                    "SELECT EXISTS(SELECT 1 FROM statuses WHERE yellow = true AND username = ANY($1))",
                )
                .bind(names)
                .fetch_one(pool)
                .await?
            }
            _ => {
                sqlx::query_scalar("SELECT EXISTS(SELECT 1 FROM statuses WHERE yellow = true)")
                    .fetch_one(pool)
                    .await?
            }
        };

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

    pub async fn colors_as_booleans(
        pool: &PgPool,
        usernames: Option<&[String]>,
    ) -> Result<ColorsAsBooleans, sqlx::Error> {
        let colors = Self::colors(pool, usernames).await?;
        Ok(ColorsAsBooleans {
            red: colors.red.as_bool().map_or(true, |b| b), // number means truthy
            yellow: colors.yellow,
            green: colors.green,
        })
    }

    /// Returns "RYG" string where uppercase means on, lowercase means off.
    pub async fn ryg(pool: &PgPool, usernames: Option<&[String]>) -> Result<String, sqlx::Error> {
        let colors = Self::colors(pool, usernames).await?;
        let r = if colors.red != serde_json::Value::Bool(false) { 'R' } else { 'r' };
        let y = if colors.yellow { 'Y' } else { 'y' };
        let g = if colors.green { 'G' } else { 'g' };
        Ok(format!("{r}{y}{g}"))
    }

    /// Returns the combined status string like "passing", "failing-building", etc.
    pub async fn current_status(pool: &PgPool, usernames: Option<&[String]>) -> Result<String, sqlx::Error> {
        let has_red: bool = match usernames {
            Some(names) if !names.is_empty() => {
                sqlx::query_scalar(
                    "SELECT EXISTS(SELECT 1 FROM statuses WHERE red = true AND username = ANY($1))",
                )
                .bind(names)
                .fetch_one(pool)
                .await?
            }
            _ => {
                sqlx::query_scalar("SELECT EXISTS(SELECT 1 FROM statuses WHERE red = true)")
                    .fetch_one(pool)
                    .await?
            }
        };

        let has_yellow: bool = match usernames {
            Some(names) if !names.is_empty() => {
                sqlx::query_scalar(
                    "SELECT EXISTS(SELECT 1 FROM statuses WHERE yellow = true AND username = ANY($1))",
                )
                .bind(names)
                .fetch_one(pool)
                .await?
            }
            _ => {
                sqlx::query_scalar("SELECT EXISTS(SELECT 1 FROM statuses WHERE yellow = true)")
                    .fetch_one(pool)
                    .await?
            }
        };

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

    /// Find devices that are watching this status.
    pub async fn devices(&self, pool: &PgPool) -> Result<Vec<super::device::Device>, sqlx::Error> {
        let name = self.name();
        let username = self.username.as_deref().unwrap_or("");

        sqlx::query_as::<_, super::device::Device>(
            "SELECT * FROM devices WHERE usernames @> ARRAY[$1]::varchar[] OR projects @> ARRAY[$2]::varchar[]",
        )
        .bind(username)
        .bind(&name)
        .fetch_all(pool)
        .await
    }

    /// Upsert a status by service + username + project_name + workflow.
    pub async fn upsert(
        pool: &PgPool,
        service: &str,
        project_id: Option<&str>,
        username: Option<&str>,
        project_name: Option<&str>,
        workflow: Option<&str>,
        red: Option<bool>,
        yellow: Option<bool>,
    ) -> Result<Self, sqlx::Error> {
        // Try to find existing
        let existing = sqlx::query_as::<_, Status>(
            "SELECT * FROM statuses WHERE service = $1 AND \
             (username IS NOT DISTINCT FROM $2) AND \
             (project_name IS NOT DISTINCT FROM $3) AND \
             (workflow IS NOT DISTINCT FROM $4) AND \
             (project_id IS NOT DISTINCT FROM $5)",
        )
        .bind(service)
        .bind(username)
        .bind(project_name)
        .bind(workflow)
        .bind(project_id)
        .fetch_optional(pool)
        .await?;

        match existing {
            Some(mut status) => {
                if let Some(r) = red {
                    status.red = Some(r);
                }
                if let Some(y) = yellow {
                    status.yellow = Some(y);
                }
                // Update username/project_name if provided (Travis sets these from payload)
                if username.is_some() {
                    status.username = username.map(String::from);
                }
                if project_name.is_some() {
                    status.project_name = project_name.map(String::from);
                }

                sqlx::query_as::<_, Status>(
                    "UPDATE statuses SET red = $1, yellow = $2, username = $3, project_name = $4, updated_at = NOW() \
                     WHERE id = $5 RETURNING *",
                )
                .bind(status.red)
                .bind(status.yellow)
                .bind(&status.username)
                .bind(&status.project_name)
                .bind(status.id)
                .fetch_one(pool)
                .await
            }
            None => {
                sqlx::query_as::<_, Status>(
                    "INSERT INTO statuses (service, project_id, username, project_name, workflow, red, yellow, created_at, updated_at) \
                     VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW()) RETURNING *",
                )
                .bind(service)
                .bind(project_id)
                .bind(username)
                .bind(project_name)
                .bind(workflow)
                .bind(red)
                .bind(yellow)
                .fetch_one(pool)
                .await
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_name() {
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
}
