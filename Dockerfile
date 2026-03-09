# syntax=docker/dockerfile:1

# Build stage
FROM rust:1 AS build

WORKDIR /app

# Install sqlx-cli for migrations
RUN cargo install sqlx-cli --no-default-features --features postgres

# Copy manifests first for dependency caching
COPY Cargo.toml Cargo.lock ./

# Create a dummy main to build dependencies
RUN mkdir src && echo "fn main() {}" > src/main.rs && echo "" > src/lib.rs
RUN cargo build --release && rm -rf src

# Copy the actual source code and assets
COPY src ./src
COPY migrations ./migrations
COPY templates ./templates
COPY public ./public
COPY tests ./tests

# Touch main.rs so cargo rebuilds with actual code
RUN touch src/main.rs src/lib.rs
RUN cargo build --release

# Runtime stage
FROM debian:stable-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates libpq5 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the binary
COPY --from=build /app/target/release/buildlight ./bin/buildlight

# Copy sqlx-cli for running migrations manually if needed
COPY --from=build /usr/local/cargo/bin/sqlx ./bin/sqlx

# Copy runtime assets
COPY --from=build /app/migrations ./migrations
COPY --from=build /app/templates ./templates
COPY --from=build /app/public ./public

# Run as non-root
RUN groupadd --system --gid 1000 app && \
    useradd --system --uid 1000 --gid app app
USER 1000:1000

EXPOSE 8080
CMD ["./bin/buildlight"]
