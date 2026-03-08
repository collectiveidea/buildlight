DROP INDEX index_statuses_on_status;
DROP INDEX index_statuses_on_project_id_and_status;
DROP INDEX index_statuses_on_project_id_and_status_and_created_at;

ALTER TABLE statuses RENAME COLUMN status TO color;

CREATE INDEX index_statuses_on_color ON statuses (color);
CREATE INDEX index_statuses_on_project_id_and_color ON statuses (project_id, color);
CREATE INDEX index_statuses_on_project_id_and_color_and_created_at ON statuses (project_id, color, created_at);
