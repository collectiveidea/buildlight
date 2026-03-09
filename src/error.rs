use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};

#[derive(Debug)]
pub enum AppError {
    NotFound,
    BadRequest,
    Internal(String),
    Database(sqlx::Error),
    Template(tera::Error),
}

impl std::fmt::Display for AppError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            AppError::NotFound => write!(f, "Not found"),
            AppError::BadRequest => write!(f, "Bad request"),
            AppError::Internal(msg) => write!(f, "Internal error: {msg}"),
            AppError::Database(e) => write!(f, "Database error: {e}"),
            AppError::Template(e) => write!(f, "Template error: {e}"),
        }
    }
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let status = match &self {
            AppError::NotFound => StatusCode::NOT_FOUND,
            AppError::BadRequest => StatusCode::BAD_REQUEST,
            AppError::Internal(_) | AppError::Database(_) | AppError::Template(_) => {
                tracing::error!("{self}");
                StatusCode::INTERNAL_SERVER_ERROR
            }
        };

        status.into_response()
    }
}

impl From<sqlx::Error> for AppError {
    fn from(e: sqlx::Error) -> Self {
        match e {
            sqlx::Error::RowNotFound => AppError::NotFound,
            other => AppError::Database(other),
        }
    }
}

impl From<tera::Error> for AppError {
    fn from(e: tera::Error) -> Self {
        AppError::Template(e)
    }
}
