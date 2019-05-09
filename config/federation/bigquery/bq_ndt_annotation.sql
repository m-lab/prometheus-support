#standardSQL
-- bq_ndt_annotation calculates the number of successfully annotated NDT tests
-- per day.
--
-- This query exports two values:
--   bq_ndt_annotation_geo_success -- number of successfully geo annotated NDT tests.
--   bq_ndt_annotation_asn_success -- number of successfully asn annotated NDT tests.
--   bq_ndt_annotation_total -- total number of tests checked for annotations.

SELECT
  COUNTIF(latitude IS NOT NULL AND longitude IS NOT NULL) AS value_geo_success,
  COUNTIF(asn IS NOT NULL) AS value_asn_success,
  COUNT(*) AS value_total

FROM (
  SELECT
    connection_spec.client_geolocation.latitude as latitude,
    connection_spec.client_geolocation.longitude as longitude,
    connection_spec.client.network.asn as asn

  FROM
    `measurement-lab.ndt.web100`

  WHERE
    -- For faster queries we use `partition_date` boundaries. And, to
    -- guarantee the partition_date data is "complete" (all data collected
    -- and parsed) we should wait 36 hours after start of a given day.
    -- The following is equivalent to the pseudo code: date(now() - 12h) - 1d
    partition_date = DATE(TIMESTAMP_SUB(TIMESTAMP_TRUNC(TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 12 HOUR), DAY), INTERVAL 24 HOUR))

  GROUP BY
    log_time,
    web100_log_entry.connection_spec.remote_ip,
    web100_log_entry.connection_spec.local_ip,
    web100_log_entry.connection_spec.remote_port,
    connection_spec.client_geolocation.latitude,
    connection_spec.client_geolocation.longitude,
    web100_log_entry.connection_spec.local_port
)
