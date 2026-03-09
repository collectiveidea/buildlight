CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE statuses (
    id BIGSERIAL PRIMARY KEY,
    project_id VARCHAR,
    project_name VARCHAR,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    payload TEXT,
    red BOOLEAN,
    yellow BOOLEAN,
    username VARCHAR,
    service VARCHAR NOT NULL,
    workflow VARCHAR
);

CREATE INDEX index_statuses_on_project_id ON statuses (project_id);
CREATE INDEX index_statuses_on_project_name ON statuses (project_name);
CREATE INDEX index_statuses_on_red ON statuses (red);
CREATE INDEX index_statuses_on_yellow ON statuses (yellow);
CREATE INDEX index_statuses_on_username ON statuses (username);
CREATE INDEX index_statuses_on_username_and_project_name ON statuses (username, project_name);
CREATE INDEX index_statuses_on_username_and_red ON statuses (username, red);
CREATE INDEX index_statuses_on_username_and_yellow ON statuses (username, yellow);

CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usernames VARCHAR[] NOT NULL DEFAULT '{}',
    projects VARCHAR[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    identifier VARCHAR,
    name VARCHAR NOT NULL,
    webhook_url VARCHAR,
    slug CITEXT,
    status VARCHAR,
    status_changed_at TIMESTAMP
);

CREATE UNIQUE INDEX index_devices_on_identifier ON devices (identifier);
CREATE INDEX index_devices_on_name ON devices (name);
CREATE UNIQUE INDEX index_devices_on_slug ON devices (slug);
