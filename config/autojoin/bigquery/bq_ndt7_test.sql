#standardSQL
-- bq_ndt7_test calculates the number of BigQuery rows that exist for Autojoin
-- clients for the last 24 hours, offset by 4 hours. Daily autoloaded data is
-- processed every 3h, and the Jostler is configured to not hold data for more
-- than 1h. This means that within roughly 4h _most_ autoloaded experiment data
-- should be in BigQuery.
--
-- This query exports a single value:
--   bq_ndt7_test_total -- number of ndt7 rows.

SELECT
  COUNT(*) AS value_total
FROM
  `mlab-autojoin.autoload_v2_ndt.ndt7_union`
WHERE
  date > DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)
  AND raw.StartTime < TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 4 HOUR)
  AND raw.StartTime > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 28 HOUR)

