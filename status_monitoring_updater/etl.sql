-- Delete current statuses and replace them with the new ones
DELETE FROM instance;
INSERT INTO instance
SELECT
    host,
    CAST(CAST(status AS text) AS instance_status),
    reason,
    date
FROM imported_schema.statuses;

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
