#standardSQL
-- bq_billing_hourly calculates the hourly GCP billing costs and credits from
-- two days prior. Because GCP billing information is exported to BigQuery
-- periodically, it may take up to 1.6 days after a given billing hour before
-- all billing information is available in BigQuery. To keep the offset simple,
-- we round up to 2days.
--
-- This query exports two values:
--   bq_billing_hourly_costs - total real costs.
--   bq_billing_hourly_credits - total credits that offset costs, this includes
--     the sum of billing credits and "sustained usage" discounts.
--
-- Each metric above has multiple labels that allow aggregation across various
-- dimensions.

WITH recent_billing AS (
  SELECT
    -- Calculate the most recent hour boundary where we're confident all data is up to date.
    TIMESTAMP_SUB(TIMESTAMP_TRUNC(CURRENT_TIMESTAMP(), HOUR), INTERVAL 2 DAY) AS start_hour_minus_2d,
    *
  FROM
    `mlab-oti.billing.unified`
  WHERE
    -- Rows for a given billing hour may be exported up to 1.6 days later.
    -- So, only look for updates over the last two days.
    partition_time >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY))
)

, net_hourly_billing AS (
  SELECT
    CONCAT(service.description, ":", sku.description) AS service,
    FARM_FINGERPRINT(billing_account_id) AS billing, -- obscure the actual ids.
    project.id AS project,
    location.location AS location,
    invoice.month AS month,
    -- Multiple credits are possible. i.e. "sustained use" discounts and billing account credits.
    -- This calcluates the effective, net credits for a given row by grouping on all other fields.
    SUM(credits.amount) AS net_credits,
    cost
  FROM
    recent_billing, UNNEST(credits) AS credits
  WHERE
    -- Select only rows from "recent_billing" that match the current usage hour from 2 days ago.
    start_hour_minus_2d = usage_start_time
  GROUP BY
    service, billing, project, location, month, cost
)

SELECT
  -- metric labels.
  service, billing, project, location, month,
  -- metric values.
  SUM(net_credits) AS value_credits,
  SUM(cost) AS value_costs
FROM
  net_hourly_billing
GROUP BY
  service, billing, project, location, month
ORDER BY
  value_costs DESC
