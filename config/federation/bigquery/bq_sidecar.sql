#standardSQL
-- bq_sidecar calculates the total number of ndt7 tests and how many matching
-- scamper1 rows per site, since this type of configuration failure may affect
-- individual sites.
--
-- This query exports two values:
--   bq_sidecar_ndt_total -- number of ndt7 rows.
--   bq_sidecar_scamper1_matching -- number of scamper1 rows matching ndt7 rows.
--
-- Each value above also has a "site" label.

WITH scamper1 AS (
    SELECT
      *
    FROM
      `measurement-lab.ndt.scamper1`
    WHERE
      date = DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)
), ndt7 AS (
    SELECT
      *
    FROM
      `measurement-lab.ndt.ndt7`
    WHERE
      date = DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)
)

SELECT
  n.server.Site AS site,
  COUNT(*) AS value_ndt_total,
  COUNTIF(s.id IS NOT NULL) AS value_scamper1_matching,

FROM ndt7 AS n
  FULL OUTER JOIN scamper1 AS s
  ON n.id = s.id

WHERE
  n.id IS NOT NULL

GROUP BY
  n.server.Site

HAVING
  value_ndt_total > 1000
