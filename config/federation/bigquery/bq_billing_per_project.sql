#standardSQL

bq_billing_per_project calculates the average GCP billing costs from the last
30 days for each project.  Because GCP billing information is exported to
BigQuery periodically, it may take up to 1.6 days after a given billing hour
before all billing information is available in BigQuery. The metrics created by
this query can be used for alerting.

-- This query exports a single value: bq_billing_per_project

SELECT
  CASE
    WHEN DATE(usage_start_time) = CURRENT_DATE() THEN "today"
    WHEN DATE(usage_start_time) = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) THEN "yesterday"
    WHEN DATE(usage_start_time) = DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY) THEN "before_yesterday"
    WHEN DATE(usage_start_time) <= CURRENT_DATE() THEN "month"
END
  AS period,
  project.id AS project,
  SUM(cost) AS value
FROM
  `mlab-oti.billing.unified`
WHERE
  DATE(usage_start_time) BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 31 DAY)
  AND CURRENT_DATE
  AND usage_start_time IS NOT NULL
  AND project.id IS NOT NULL
  AND cost IS NOT NULL
GROUP BY
  project,
  period

