ALTER TABLE statuses ADD COLUMN service VARCHAR;
UPDATE statuses SET service = 'travis' WHERE service IS NULL;
ALTER TABLE statuses ALTER COLUMN service SET NOT NULL;
