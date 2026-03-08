CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usernames VARCHAR[] NOT NULL DEFAULT '{}',
    projects VARCHAR[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);
