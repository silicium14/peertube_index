-- This script must be ran with psql because it contains psql commands

-- Setup
CREATE DATABASE peertube_index;
\c peertube_index;

CREATE TYPE instance_status AS ENUM ('discovered', 'ok', 'error', 'banned');
CREATE TABLE IF NOT EXISTS instance (
    host varchar PRIMARY KEY NOT NULL,
    status instance_status NOT NULL,
    reason varchar,
    date timestamp NOT NULL
);

CREATE TABLE IF NOT EXISTS history (
    status instance_status,
    count int NOT NULL,
    import_time timestamp,
    PRIMARY KEY(status, import_time)
);

-- Import
CREATE TEMPORARY TABLE IF NOT EXISTS json_import (document jsonb);
\copy json_import from '/tmp/statuses.json' with csv quote e'\x01' delimiter e'\x02';

-- Delete current statuses and replace them with the new ones
DELETE FROM instance;
INSERT INTO instance
SELECT *
FROM jsonb_populate_recordset(
    null::instance,
    (SELECT document FROM json_import)
);

-- Compute aggregations on current statuses and append the result to the history
INSERT INTO history (status, count, import_time)
WITH stats AS (
    SELECT status,
           count(host) as count
    FROM instance
    GROUP BY status
)
SELECT stats.status,
       stats.count,
       :import_time
FROM stats;
