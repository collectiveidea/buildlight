DROP INDEX index_statuses_on_color;
DROP INDEX index_statuses_on_project_id_and_color;
DROP INDEX index_statuses_on_project_id_and_color_and_created_at;

ALTER TABLE statuses ADD COLUMN red BOOLEAN;
ALTER TABLE statuses ADD COLUMN yellow BOOLEAN;
ALTER TABLE statuses DROP COLUMN color;

CREATE INDEX index_statuses_on_red ON statuses (red);
CREATE INDEX index_statuses_on_yellow ON statuses (yellow);
