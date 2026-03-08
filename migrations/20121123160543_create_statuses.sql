CREATE TABLE statuses (
    id SERIAL PRIMARY KEY,
    project_id VARCHAR,
    project_name VARCHAR,
    status VARCHAR,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE INDEX index_statuses_on_project_id ON statuses (project_id);
CREATE INDEX index_statuses_on_project_name ON statuses (project_name);
CREATE INDEX index_statuses_on_status ON statuses (status);
CREATE INDEX index_statuses_on_project_id_and_status ON statuses (project_id, status);
CREATE INDEX index_statuses_on_project_id_and_status_and_created_at ON statuses (project_id, status, created_at);
