#[derive(Clone, Debug)]
pub struct Config {
    pub database_url: String,
    pub port: u16,
    pub host: String,
    pub particle_access_token: Option<String>,
}

impl Config {
    pub fn from_env() -> Self {
        dotenvy::dotenv().ok();

        Self {
            database_url: std::env::var("DATABASE_URL")
                .unwrap_or_else(|_| "postgres://localhost/buildlight_development".into()),
            port: std::env::var("PORT")
                .ok()
                .and_then(|p| p.parse().ok())
                .unwrap_or(3001),
            host: std::env::var("HOST").unwrap_or_else(|_| "localhost:3001".into()),
            particle_access_token: std::env::var("PARTICLE_ACCESS_TOKEN").ok().filter(|s| !s.is_empty()),
        }
    }
}
