#standardSQL

-- bq_billing calculates the average GCP billing costs from the last 30 days.
-- Because GCP billing information is exported to BigQuery periodically, it may
-- take up to 1.6 days after a given billing hour before all billing information
-- is available in BigQuery. To keep the offset simple, we skip the most recent 2 days.
--
-- This query exports three aggregated values:
--    bq_billing_average_daily - average daily costs calculated from the last 30 days.
--    bq_billing_monthly - actual costs from the last 30 days.
--    bq_billing_average_annual - average annual costs calculated from the daily average * 365.
--
-- To monitor storage costs, specifically, it exports the following storage values.
--    bq_billing_average_daily_storage - average daily storage costs calculated from the last 30 days.
--    bq_billing_today_storage - total storage costs for today's date (UTC).
--    bq_billing_yesterday_storage - total storage costs for yesterday's date (UTC).
--    bq_billing_before_yesterday_storage - total storage costs for the day before yesterday (UTC).
--
-- These metrics have no additional labels and are meant for use in billing alerts.

WITH billing AS(
  SELECT
    CASE
      WHEN DATE(usage_start_time) = CURRENT_DATE() THEN "today"
      WHEN DATE(usage_start_time) = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) THEN "yesterday"
      WHEN DATE(usage_start_time) = DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY) THEN "before_yesterday"
      WHEN DATE(usage_start_time) <= DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY) THEN "month"
      END
      AS period,
    IF(service.description LIKE '%Storage%', "storage", "all") AS service,
    cost
  FROM
    `mlab-oti.billing.unified`
  WHERE
    DATE(usage_start_time) BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 31 DAY) AND CURRENT_DATE
    AND usage_start_time IS NOT NULL AND project.id IS NOT NULL AND cost IS NOT NULL
)

SELECT
  -- Aggregated metrics.
  SUM(IF(period = "month", cost, 0))/30 AS value_average_daily,
  SUM(IF(period = "month", cost, 0)) AS value_average_monthly,
  365*SUM(IF(period = "month", cost, 0))/30 AS value_average_annual,
  -- Storage metrics.
  SUM(IF(period = "month" AND service = "storage", cost, 0))/30 AS value_average_daily_storage,
  SUM(IF(period = "today" AND service = "storage", cost, 0)) AS value_today_storage,
  SUM(IF(period = "yesterday" AND service = "storage", cost, 0)) AS value_yesterday_storage,
  SUM(IF(period = "before_yesterday" AND service = "storage", cost, 0)) AS value_before_yesterday_storage
FROM
  billing