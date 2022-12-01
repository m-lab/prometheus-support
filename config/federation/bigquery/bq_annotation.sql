#standardSQL
-- bq_annotation calculates the number of successfully annotated tests per day,
-- per datatype.
--
-- This query exports three values:
--   bq_annotation_geo_success -- number of successfully geo annotated tests.
--   bq_annotation_asn_success -- number of successfully asn annotated tests.
--   bq_annotation_total -- total number of tests checked for annotations.
--
-- Each value above also has a "datatype" label.

WITH recent_ndt_tcpinfo AS (
  SELECT "ndt/tcpinfo" AS datatype, client.Geo.Latitude, client.Geo.Longitude, systems.ASNs AS asn
  FROM `measurement-lab.ndt.tcpinfo` LEFT JOIN UNNEST(client.Network.Systems) AS systems
  WHERE date = DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)
), recent_ndt_ndt7 AS (
  SELECT "ndt/ndt7" AS datatype, client.Geo.Latitude, client.Geo.Longitude, systems.ASNs AS asn
  FROM   `measurement-lab.ndt.ndt7` LEFT JOIN UNNEST(client.Network.Systems) AS systems
  WHERE date = DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)
), recent_ndt_ndt5 AS (
  SELECT "ndt/ndt5" AS datatype, client.Geo.Latitude, client.Geo.Longitude, systems.ASNs AS asn
  FROM   `measurement-lab.ndt.ndt5` LEFT JOIN UNNEST(client.Network.Systems) AS systems
  WHERE date = DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)
), recent_ndt_scamper1 AS (
  SELECT "ndt/scamper1" AS datatype, client.Geo.Latitude, client.Geo.Longitude, systems.ASNs AS asn
  FROM   `measurement-lab.ndt.scamper1` LEFT JOIN UNNEST(client.Network.Systems) AS systems
  WHERE date = DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)
)

SELECT
  COUNTIF(Latitude IS NOT NULL AND Longitude IS NOT NULL) AS value_geo_success,
  COUNTIF(asn IS NOT NULL AND ARRAY_LENGTH(asn) != 0) AS value_asn_success,
  COUNT(*) AS value_total,
  datatype

FROM (
   SELECT * FROM recent_ndt_tcpinfo
   UNION ALL
   SELECT * FROM recent_ndt_ndt7
   UNION ALL
   SELECT * FROM recent_ndt_ndt5
   UNION ALL
   SELECT * FROM recent_ndt_scamper1
)
GROUP BY
  datatype
