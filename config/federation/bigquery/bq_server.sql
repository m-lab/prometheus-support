WITH site_city_country AS (
  SELECT
    CASE
    WHEN date between DATE_SUB(CURRENT_DATE(), INTERVAL 360 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 353 DAY)
      THEN -360
    WHEN date between DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 173 DAY)
      THEN -180
    WHEN date between DATE_SUB(CURRENT_DATE(), INTERVAL  90 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 83 DAY)
      THEN -90
    WHEN date between DATE_SUB(CURRENT_DATE(), INTERVAL  30 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 23 DAY)
      THEN -30
    WHEN date between DATE_SUB(CURRENT_DATE(), INTERVAL   7 DAY) AND CURRENT_DATE()
      THEN -7
    ELSE
      0
    END as period,
    server.Site AS site,
    REGEXP_EXTRACT(server.Site, "([a-z]{3}).*") AS city,
    server.Geo.CountryCode AS country
  FROM
    `measurement-lab.ndt.ndt7`
  WHERE
       date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 360 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 353 DAY)
    OR date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 173 DAY)
    OR date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL  90 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 83 DAY)
    OR date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL  30 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 23 DAY)
    OR date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL   7 DAY) AND CURRENT_DATE()
), raw_counts AS (
  SELECT
    period,
    COUNT(distinct site) AS sites_count,
    COUNT(distinct city) AS cities_count,
    COUNT(distinct country) AS countries_count
  FROM
    site_city_country
  GROUP BY
    period
  ORDER BY
    period
)

SELECT
  CAST(period AS STRING) AS le,
  SUM(sites_count) OVER ( ORDER BY period ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS value_sites_count,
  SUM(cities_count) OVER ( ORDER BY period ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS value_cities_count,
  SUM(countries_count) OVER ( ORDER BY period ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS value_countries_count,
FROM
  raw_counts
ORDER BY
  period
