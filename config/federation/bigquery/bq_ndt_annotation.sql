#standardSQL
-- bq_ndt_annotation calculates the ratio of successfully annotated NDT tests
-- per day.
--
-- This query exports two values:
--   bq_ndt_annotation_ratio -- ratio of successfully annotated NDT tests.
--   bq_ndt_annotation_tests -- number of tests used to calculate ratio.

SELECT
  CASE COUNT(*)
    -- When the test count is zero the safe_divide returns NULL.
    -- Since bq_ndt_annotation_ratio is a success metric, zero is appropriate.
    WHEN = 0 THEN 0
    ELSE SAFE_DIVIDE(COUNTIF(latitude IS NOT NULL AND longitude IS NOT NULL), COUNT(*))
  END as value_ratio,
  COUNT(*) AS value_tests

FROM (
  SELECT
    connection_spec.client_geolocation.latitude as latitude,
    connection_spec.client_geolocation.longitude as longitude

  FROM
    `measurement-lab.base_tables.ndt`

  WHERE
    -- For faster queries we use _PARTITIONTIME boundaries. And, to
    -- guarantee the _PARTITIONTIME data is "complete" (all data collected
    -- and parsed) we should wait 36 hours after start of a given day.
    -- The following is equivalent to the pseudo code: date(now() - 12h) - 1d
    _PARTITIONTIME = TIMESTAMP_SUB(TIMESTAMP_TRUNC(TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 12 HOUR), DAY), INTERVAL 24 HOUR)

  GROUP BY
    log_time,
    web100_log_entry.connection_spec.remote_ip,
    web100_log_entry.connection_spec.local_ip,
    web100_log_entry.connection_spec.remote_port,
    connection_spec.client_geolocation.latitude,
    connection_spec.client_geolocation.longitude,
    web100_log_entry.connection_spec.local_port
)
