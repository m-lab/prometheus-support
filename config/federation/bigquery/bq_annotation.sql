#standardSQL
-- bq_annotation calculates the number of successfully annotated tests per day.
--
-- This query exports three values:
--   bq_annotation_geo_success -- number of successfully geo annotated tests.
--   bq_annotation_asn_success -- number of successfully asn annotated tests.
--   bq_annotation_total -- total number of tests checked for annotations.
--
-- Each value above also has a "datatype" label.
--
-- TODO(https://github.com/m-lab/dev-tracker/issues/510): once gardener supports
-- "daily" processing, update queries to look at the last 24hrs.
--
-- TODO(https://github.com/m-lab/dev-tracker/issues/496): once parsers write
-- directly to canonical tables for k8s platform data, enumerate all supported
-- datatypes.

WITH recent_ndt_tcpinfo AS (
  SELECT "ndt/tcpinfo" AS datatype, Client.Geo.latitude, Client.Geo.longitude, systems.ASNs AS asn
  FROM `{{PROJECT}}.ndt_raw.tcpinfo_legacy`, UNNEST(Client.Network.Systems) AS systems
  WHERE ParseInfo.ParseTime >= (TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR))
), recent_paris1 AS (
  SELECT "aggregate/paris1" AS datatype, Source.Geo.latitude, Destination.Geo.longitude, systems.ASNs AS asn
  FROM   `{{PROJECT}}.ndt_raw.paris1_legacy`, UNNEST(Destination.Network.Systems) AS systems
  WHERE  ParseInfo.ParseTime >= (TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR))
)

SELECT

  COUNTIF(latitude IS NOT NULL AND longitude IS NOT NULL) AS value_geo_success,
  COUNTIF(asn IS NOT NULL AND ARRAY_LENGTH(asn) != 0) AS value_asn_success,
  COUNT(*) AS value_total,
  datatype

FROM (
   SELECT * FROM recent_ndt_tcpinfo
   UNION ALL
   SELECT * FROM recent_paris1
)
GROUP BY
  datatype
