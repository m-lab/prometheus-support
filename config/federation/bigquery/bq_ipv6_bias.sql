#standardSQL
-- bq_ipv6_bias collects the number of daily tests broken down by site, address
-- type and window scale. The query reports data from two days ago according to
-- the public ndt table's _PARTITIONTIME.

SELECT
  SUBSTR(connection_spec.server_hostname, 7, 5) AS site,
  IF(REGEXP_CONTAINS(connection_spec.server_ip, ':'), "v6", "v4") AS address_type,
  CASE WHEN -1 = web100_log_entry.snap.SndWindScale THEN "wsnone"
       WHEN 0 = web100_log_entry.snap.SndWindScale  THEN "ws0"
       WHEN 1 <= web100_log_entry.snap.SndWindScale AND web100_log_entry.snap.SndWindScale <= 2 THEN "ws12"
       WHEN 3 <= web100_log_entry.snap.SndWindScale AND web100_log_entry.snap.SndWindScale <= 5 THEN "ws345"
       WHEN 6 = web100_log_entry.snap.SndWindScale  THEN "ws6"
       WHEN 7 = web100_log_entry.snap.SndWindScale  THEN "ws7"
       WHEN 8 = web100_log_entry.snap.SndWindScale  THEN "ws8"
       WHEN 9 <= web100_log_entry.snap.SndWindScale THEN "ws9up"
       ELSE "wsUnknown"
       END AS window_scale,
   COUNT(*) AS value

FROM
    `measurement-lab.public.ndt`

WHERE
    -- To guarantee the period queried is up to date (all data collected and
    -- parsed), we should wait 36hours after the start of day. To also use
    -- _PARTITIONTIME boundaries, we must look 2 days in the past.
    _PARTITIONTIME = TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY))

GROUP BY
   site, address_type, window_scale

ORDER BY
   site, address_type, window_scale
