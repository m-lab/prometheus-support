#standardSQL

-- bq_billing calculates the average GCP billing costs from the last 30 days.
-- Because GCP billing information is exported to BigQuery periodically, it may
-- take up to 1.6 days after a given billing hour before all billing information
-- is available in BigQuery. To keep the offset simple, we skip the most recent 2 days.
--
-- This query exports three values:
--    bq_billing_average_daily - average daily costs calculated from the last 30 days.
--    bq_billing_monthly - actual costs from the last 30 days.
--    bq_billing_average_annual - average annual costs calculated from the daily average * 365.
--
-- These metrics have no additional labels and are meant for use in billing alerts.

SELECT
  SUM(cost)/720 AS value_average_hourly,
  SUM(cost)/30 AS value_average_daily,
  SUM(cost) AS value_average_monthly,
  365*SUM(cost)/30 AS value_average_annual,
FROM
  `mlab-oti.billing.unified`
WHERE
  DATE(usage_start_time) BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 31 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)
  AND usage_start_time IS NOT NULL AND project.id IS NOT NULL AND cost IS NOT NULL
