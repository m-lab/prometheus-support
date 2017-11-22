#standardSQL

SELECT
  direction,
  machine,
  COUNTIF(
          log_time >= TIMESTAMP_SECONDS(CAST(UNIX_SECONDS(CURRENT_TIMESTAMP()) / REFRESH_RATE_SEC AS INT64) * REFRESH_RATE_SEC - (36 * 60 * 60))
      AND log_time <  TIMESTAMP_SECONDS(CAST(UNIX_SECONDS(CURRENT_TIMESTAMP()) / REFRESH_RATE_SEC AS INT64) * REFRESH_RATE_SEC - (36 * 60 * 60) + REFRESH_RATE_SEC)
  ) as value

FROM (
  SELECT
      log_time,
      direction,
      machine
  FROM (
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
      -- Use ndt_fast, which excludes rows from EB
      `measurement-lab.public.ndt`
    WHERE
          _PARTITIONTIME >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 72 HOUR)
      AND _PARTITIONTIME <= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
      AND log_time >= TIMESTAMP_SECONDS(CAST(UNIX_SECONDS(CURRENT_TIMESTAMP()) / REFRESH_RATE_SEC AS INT64) * REFRESH_RATE_SEC - (36 * 60 * 60))
      AND log_time <  TIMESTAMP_SECONDS(CAST(UNIX_SECONDS(CURRENT_TIMESTAMP()) / REFRESH_RATE_SEC AS INT64) * REFRESH_RATE_SEC - (36 * 60 * 60) + (REFRESH_RATE_SEC * 6))
  )
  WHERE
    row_number = 1
)

GROUP BY
  machine, direction

ORDER BY
  machine, direction
