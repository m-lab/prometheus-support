#standardSQL
-- bq_ipv6_bias collects the number of daily tests broken down by site, address
-- type and window scale. The query reports data from the most recent "complete"
-- day, where complete is defined as current time is at least 36hours since
-- start of that day.

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
    -- parsed), we should wait 36hours after the start of a given day. To also
    -- use _PARTITIONTIME boundaries, we must look at least one day in the past.
    -- The following calculates the most recent "complete" _PARTITIONTIME. The following
    -- should be equivalent to pseudo code: TruncateTimeToDay(now() - 12h) - 1d
    _PARTITIONTIME = TIMESTAMP_SUB(TIMESTAMP_TRUNC(TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 12 HOUR), DAY), INTERVAL 24 HOUR)

GROUP BY
   site, address_type, window_scale

ORDER BY
   site, address_type, window_scale
