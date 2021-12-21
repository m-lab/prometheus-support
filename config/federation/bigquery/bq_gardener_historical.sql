#standardSQL
-- bq_gardener_historical counts the number of historical dates
-- processed in the last 24 hours for each v2 datatype.

WITH all_types AS (
  SELECT
    "raw_ndt.ndt7" AS datatype,
    id,
    date,
    parser.Time as parseTime,
  FROM
    `{{PROJECT}}.raw_ndt.ndt7`
  WHERE date > date('2019-01-01')
  UNION ALL
  SELECT
    "raw_ndt.annotation" AS datatype,
    id,
    date,
    parser.Time as parseTime,
  FROM
    `{{PROJECT}}.raw_ndt.annotation`
  WHERE date > date('2019-01-01')
  UNION ALL
  SELECT
    "raw_ndt.hopannotation1" AS datatype,
    id,
    date,
    parser.Time as parseTime,
  FROM
    `{{PROJECT}}.raw_ndt.hopannotation1`
  WHERE date > date('2019-01-01')
  UNION ALL
  SELECT
    "raw_ndt.pcap" AS datatype,
    id,
    date,
    parser.Time as parseTime,
  FROM
    `{{PROJECT}}.raw_ndt.pcap`
  WHERE date > date('2019-01-01')
  UNION ALL
  SELECT
    "raw_ndt.scamper1" AS datatype,
    id,
    date,
    parser.Time as parseTime,
  FROM
    `{{PROJECT}}.raw_ndt.scamper1`
  WHERE date > date('2019-03-28')
)

SELECT datatype, COUNT(distinct date) AS value_throughput
FROM all_types
WHERE (parseTime
        BETWEEN TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
            AND CURRENT_TIMESTAMP())
   	AND date < DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) -- exclude daily.
GROUP BY datatype
