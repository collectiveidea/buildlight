ALTER TABLE statuses ADD COLUMN username VARCHAR;

CREATE INDEX index_statuses_on_username ON statuses (username);
CREATE INDEX index_statuses_on_username_and_project_name ON statuses (username, project_name);
CREATE INDEX index_statuses_on_username_and_red ON statuses (username, red);
CREATE INDEX index_statuses_on_username_and_yellow ON statuses (username, yellow);
