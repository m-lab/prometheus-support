SELECT
  CASE 
    WHEN connection_spec.data_direction == 0 THEN "c2s"
    WHEN connection_spec.data_direction == 1 THEN "s2c"
    ELSE "error"
    END as direction,

    CONCAT(
        REPLACE(
            REGEXP_EXTRACT(task_filename,
                           r'gs://.*-(mlab[1-4]-[a-z]{3}[0-9]+)-ndt.*.tgz'),
            "-",
            "."),
        ".measurement-lab.org") AS machine,

    count(*) as value

FROM
    [measurement-lab:public.ndt]

WHERE
    -- Count all tests in a REFRESH_RATE_SEC interval 36 hours ago.
    TIMESTAMP_TO_SEC(log_time) > INTEGER(TIMESTAMP_TO_SEC(CURRENT_TIMESTAMP()) / (REFRESH_RATE_SEC)) * (REFRESH_RATE_SEC) - (36 * 60 * 60)
AND TIMESTAMP_TO_SEC(log_time) < INTEGER(TIMESTAMP_TO_SEC(CURRENT_TIMESTAMP()) / (REFRESH_RATE_SEC)) * (REFRESH_RATE_SEC) - (36 * 60 * 60) + (REFRESH_RATE_SEC)

GROUP BY machine, direction
ORDER BY value
