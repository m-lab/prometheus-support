#standardSQL
-- bq_gardener calculates ...
--
-- Note: this query returns multiple values. So, resulting metrics will be:
--   bq_gardener_partitions
--   bq_gardener_rows_per_date_recent
--   bq_gardener_rows_per_date_last_month
--   bq_gardener_daily_done_last_3_days
--   bq_gardener_updated_within_3_days
--   bq_gardener_oldest_less_than_3_days
--   bq_gardener_oldest_less_than_7_days
--   bq_gardener_oldest_less_than_30_days
--   bq_gardener_oldest_less_than_90_days

SELECT
    datatype, 
    COUNTIF(true) AS value_partitions,
    CAST(SAFE_DIVIDE(SUM(IF(DATE_DIFF(CURRENT_DATE(), date, DAY) < 4, records, 0)),
                     COUNTIF(DATE_DIFF(CURRENT_DATE(), date, DAY) < 4)) AS INT64) AS value_rows_per_date_recent,
    CAST(SAFE_DIVIDE(SUM(IF(DATE_DIFF(CURRENT_DATE(), date, DAY) < 30, records, 0)),
                     COUNTIF(DATE_DIFF(CURRENT_DATE(), date, DAY) < 30)) AS INT64) AS value_rows_per_date_last_month,
    COUNTIF(TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), max_parse_time, HOUR) < 72 AND DATE_DIFF(CURRENT_DATE(), date, DAY) < 4) AS value_daily_done_last_3_days,
    COUNTIF(TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), max_parse_time, HOUR) < 72) AS value_updated_within_3_days,
    COUNTIF(TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), min_parse_time, HOUR) < 72) AS value_oldest_less_than_3_days,
    COUNTIF(TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), min_parse_time, HOUR) < 168) AS value_oldest_less_than_7_days,
    COUNTIF(TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), min_parse_time, DAY) < 30) AS value_oldest_less_than_30_days,
    COUNTIF(TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), min_parse_time, DAY) < 90) AS value_oldest_less_than_90_days,
FROM (
    SELECT
        "ndt/ndt7" AS datatype,
        date,
        COUNT(id) AS records,
        MIN(parser.Time) AS min_parse_time,
        MAX(parser.Time) AS max_parse_time,
    FROM
       `mlab-oti.raw_ndt.ndt7`
    GROUP BY date
    UNION ALL
    SELECT
        "ndt/annotation" AS datatype,        
        date,
        COUNT(id) AS records,
        MIN(parser.Time) AS min_parse_time,
        MAX(parser.Time) AS max_parse_time,
    FROM
       `mlab-oti.raw_ndt.annotation`
    GROUP BY date

)
GROUP BY datatype
ORDER BY datatype
