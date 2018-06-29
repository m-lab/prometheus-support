#standardSQL

SELECT
    machine,
    APPROX_QUANTILES(IF(direction = "s2c", download, NULL), 4)[OFFSET(2)] AS value_download_median_rate,
    APPROX_QUANTILES(IF(direction = "c2s", upload, NULL), 4)[OFFSET(2)] AS value_upload_median_rate,
    FORMAT("s%03dx%03d", latitude + 180, longitude + 180) as position,
    COUNT(*) AS value_tests
FROM (
    SELECT
        -- Machine
        connection_spec.server_hostname AS machine,

        -- Direction
        CASE connection_spec.data_direction
          WHEN 0 THEN "c2s"
          WHEN 1 THEN "s2c"
          ELSE "error"
          END AS direction,

        -- Download as bits-per-second
        8 * 1000000 * (web100_log_entry.snap.HCThruOctetsAcked /
              (web100_log_entry.snap.SndLimTimeRwin +
                    web100_log_entry.snap.SndLimTimeCwnd +
                        web100_log_entry.snap.SndLimTimeSnd)) AS download,

        -- Upload as bits-per-second
        8 * 1000000 * (web100_log_entry.snap.HCThruOctetsReceived /
              web100_log_entry.snap.Duration) AS upload,

        -- Client latitude, rounded to 5 degrees.
        CAST(connection_spec.client_geolocation.latitude / 10.0 as INT64) * 10 as latitude,
        -- Client longitude, rounded to 5 degrees.
        CAST(connection_spec.client_geolocation.longitude / 10.0 as INT64) * 10 as longitude

    FROM
       `measurement-lab.base_tables.ndt`

    WHERE
        -- For faster queries we use _PARTITIONTIME boundaries. And, to
        -- guarantee the _PARTITIONTIME data is "complete" (all data collected
        -- and parsed) we should wait 36 hours after start of a given day.
        -- The following is equivalent to the pseudo code:
        --     date(now() - 12h) - 1d
        _PARTITIONTIME = TIMESTAMP_SUB(TIMESTAMP_TRUNC(TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 12 HOUR), DAY), INTERVAL 24 HOUR)
        -- Basic test quality filters for safe division.
        AND web100_log_entry.snap.Duration > 0
        AND (web100_log_entry.snap.SndLimTimeRwin + web100_log_entry.snap.SndLimTimeCwnd + web100_log_entry.snap.SndLimTimeSnd) > 0
        AND web100_log_entry.snap.CountRTT > 0
        AND web100_log_entry.snap.HCThruOctetsReceived  > 0
        AND web100_log_entry.snap.HCThruOctetsAcked > 0
)
GROUP BY
    machine, latitude, longitude, position
HAVING
    value_tests > 10
    AND value_download_median_rate is not NULL
    AND value_upload_median_rate is not NULL
    AND position is not NULL
ORDER BY
    machine
