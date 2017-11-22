#standardSQL
-- bq_ndt_tests counts the number of NDT tests within a REFRESH_RATE_SEC
-- interval 36 hours earlier than the time of query. The 36 hour offset
-- maximizes the number of NDT tests processed by the pipeline for that period.

-- timestampAlign aligns the given timestamp to a multiple of alignment seconds.
-- And, before returning, timestampAlign adds the given offset to the result.
CREATE TEMPORARY FUNCTION timestampAlign (ts TIMESTAMP, alignment_seconds INT64, offset_seconds INT64)
  RETURNS TIMESTAMP
  AS (
      TIMESTAMP_ADD(
          TIMESTAMP_SECONDS(
              CAST(UNIX_SECONDS(ts) / alignment_seconds AS INT64) * alignment_seconds),
          INTERVAL offset_seconds SECOND
      )
  );

SELECT
  machine,
  direction,
  -- The inner query operates on a window 6 times larger than REFRESH_RATE_SEC.
  -- We do this so every machine is present in the result and so COUNTIF can equal
  -- zero when no tests occur during the current interval of interest.
  COUNTIF(
          log_time >= TIMESTAMP_SUB(timestampAlign(CURRENT_TIMESTAMP(), REFRESH_RATE_SEC,                0), INTERVAL 36 HOUR)
      AND log_time <  TIMESTAMP_SUB(timestampAlign(CURRENT_TIMESTAMP(), REFRESH_RATE_SEC, REFRESH_RATE_SEC), INTERVAL 36 HOUR)
  ) as value
FROM (
  -- De-duplicate results from the inner most query.
  SELECT
      log_time,
      direction,
      machine
  FROM (
    -- Return all tests from a wider range of time than our area of interest.
    SELECT
      log_time,
      CASE connection_spec.data_direction
        WHEN 0 THEN "c2s"
        WHEN 1 THEN "s2c"
        ELSE "error"
        END as direction,
      connection_spec.server_hostname AS machine,
      ROW_NUMBER() OVER (PARTITION BY test_id) row_number
    FROM
      `measurement-lab.public.ndt`
    WHERE
      -- Restrict queries to tests in the range 2d <= log_time < today()
          _PARTITIONTIME >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY))
      AND _PARTITIONTIME <  TIMESTAMP(CURRENT_DATE())
      -- Further restrict queries to a 3x refresh rate window on both sides of the interval of interest.
      AND log_time >= TIMESTAMP_SUB(timestampAlign(CURRENT_TIMESTAMP(), REFRESH_RATE_SEC, -3 * REFRESH_RATE_SEC), INTERVAL 36 HOUR)
      AND log_time <  TIMESTAMP_SUB(timestampAlign(CURRENT_TIMESTAMP(), REFRESH_RATE_SEC,  4 * REFRESH_RATE_SEC), INTERVAL 36 HOUR)
  )
  WHERE
    row_number = 1
)

GROUP BY
  machine, direction

ORDER BY
  machine, direction
