WITH ndt7_date_counts AS (
  SELECT date, COUNT(*) AS total_rows
  FROM `measurement-lab.ndt.ndt7`
  WHERE date > DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
  GROUP BY date
), ndt5_date_counts AS (
  SELECT partition_date AS date, COUNT(*) AS total_rows
  FROM `measurement-lab.ndt_raw.ndt5_legacy`
  WHERE partition_date > DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
  GROUP BY date
), total_date_counts AS (
  SELECT date, n5.total_rows + n7.total_rows AS value_count
  FROM ndt7_date_counts AS n7 JOIN ndt5_date_counts AS n5 USING(date)
  ORDER BY date desc
)

SELECT
  FORMAT("%d", -ROW_NUMBER() OVER()) AS le,
  SUM(value_count) OVER (
    ORDER BY date
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS value_count
FROM
  total_date_counts
