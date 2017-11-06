-- bq_ndt_tests counts the number of NDT tests within a REFRESH_RATE_SEC
-- interval 36 hours earlier than the time of query. The 36 hour offset
-- maximizes the number of NDT tests processed by the pipeline for that period.
#standardSQL
SELECT
  CASE connection_spec.data_direction
    WHEN 0 THEN "c2s"
    WHEN 1 THEN "s2c"
    ELSE "error"
    END as direction,

    CONCAT(
        REPLACE(
            REGEXP_EXTRACT(
                task_filename,
                r'gs://.*-(mlab[1-4]-[a-z]{3}[0-9]+)-ndt.*.tgz'),
            "-", "."),
        ".measurement-lab.org") AS machine,

    COUNT(*) as value

FROM
    `measurement-lab.public.ndt`

WHERE
    -- Count all tests with in a REFRESH_RATE_SEC interval 36 hours ago.
    -- REFRESH_RATE_SEC is a template value replaced by the bigquery exporter at run time.
    UNIX_SECONDS(log_time) > CAST(UNIX_SECONDS(CURRENT_TIMESTAMP()) / (REFRESH_RATE_SEC) AS INT64) * (REFRESH_RATE_SEC) - (36 * 60 * 60)
AND UNIX_SECONDS(log_time) < CAST(UNIX_SECONDS(CURRENT_TIMESTAMP()) / (REFRESH_RATE_SEC) AS INT64) * (REFRESH_RATE_SEC) - (36 * 60 * 60) + (REFRESH_RATE_SEC)

GROUP BY machine, direction
ORDER BY value
