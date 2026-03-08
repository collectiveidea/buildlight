ALTER TABLE devices ADD COLUMN identifier VARCHAR NOT NULL;
CREATE UNIQUE INDEX index_devices_on_identifier ON devices (identifier);
