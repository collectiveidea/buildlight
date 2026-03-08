CREATE EXTENSION IF NOT EXISTS "citext";
ALTER TABLE devices ADD COLUMN slug CITEXT;
CREATE UNIQUE INDEX index_devices_on_slug ON devices (slug);
