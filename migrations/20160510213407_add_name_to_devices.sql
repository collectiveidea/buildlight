ALTER TABLE devices ADD COLUMN name VARCHAR NOT NULL;
CREATE INDEX index_devices_on_name ON devices (name);
