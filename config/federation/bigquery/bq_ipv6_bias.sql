-- bq_ipv6_bias collects the number of tests within a given day that 
#standardSQL

SELECT
    site, address_type, window_scale, count(*) as value

FROM (
    SELECT
      substr(connection_spec.server_hostname, 7, 5) AS site,
      IF(REGEXP_CONTAINS(connection_spec.server_ip, ':'), "v6", "v4") as address_type,
      CASE WHEN web100_log_entry.snap.SndWindScale = -1 THEN "ws0"
           WHEN 1 <= web100_log_entry.snap.SndWindScale AND web100_log_entry.snap.SndWindScale <= 2 THEN "ws12"
           WHEN 3 <= web100_log_entry.snap.SndWindScale AND web100_log_entry.snap.SndWindScale <= 5 THEN "ws345"
           WHEN 6 <= web100_log_entry.snap.SndWindScale AND web100_log_entry.snap.SndWindScale <= 8 THEN "ws678"
           WHEN 9 <= web100_log_entry.snap.SndWindScale THEN "ws9up"
           ELSE "wsUnknown"
           END as window_scale

    FROM
        `measurement-lab.public.ndt`

    WHERE
        SUBSTR(connection_spec.server_hostname, 7, 5) in ('lax01', 'mia03', 'ham01', 'hnd01')
        # phase 1 IPv6 canary
    -- TODO: use _PARTITIONTIME as date boundaries. e.g. _PARTITIONTIME = (CURRENT_DATE() - 1day)
    AND UNIX_SECONDS(log_time) < CAST(UNIX_SECONDS(CURRENT_TIMESTAMP()) / (86400) AS INT64) * (86400) - (36 * 60 * 60)
    AND UNIX_SECONDS(log_time) > CAST(UNIX_SECONDS(CURRENT_TIMESTAMP()) / (86400) AS INT64) * (86400) - (36 * 60 * 60) - (86400)
)

GROUP BY
   site, address_type, window_scale

ORDER BY
   site, address_type, window_scale
