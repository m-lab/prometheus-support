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
  COUNTIF(n.id IS NOT NULL) AS value_ndt,
  COUNTIF(n.id IS NOT NULL AND s.id IS NOT NULL) AS value_matching,

FROM ndt7 AS n
  FULL OUTER JOIN scamper1 AS s
  ON n.id = s.id

WHERE
  n.id IS NOT NULL

GROUP BY
  n.server.Site

HAVING
  value_ndt > 1000
