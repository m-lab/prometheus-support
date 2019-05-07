#standardSQL

SELECT
    machine,
    REGEXP_EXTRACT(machine, "mlab[1-4].([a-z]{3}[0-9]{2}).*") as site,
    REGEXP_EXTRACT(machine, "mlab[1-4].([a-z]{3})[0-9]{2}.*") as metro,
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
          END AS direction

    FROM
       `measurement-lab.ndt.web100`

    WHERE
        -- For faster queries we use `partition_date` boundaries. And, to
        -- guarantee the partition_date data is "complete" (all data collected
        -- and parsed) we should wait 36 hours after start of a given day.
        -- The following is equivalent to the pseudo code:
        --     date(now() - 12h) - 1d
        partition_date = DATE(TIMESTAMP_SUB(TIMESTAMP_TRUNC(TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 12 HOUR), DAY), INTERVAL 24 HOUR))
        -- Basic test quality filters for safe division.
        AND web100_log_entry.snap.Duration > 0
        AND (web100_log_entry.snap.SndLimTimeRwin + web100_log_entry.snap.SndLimTimeCwnd + web100_log_entry.snap.SndLimTimeSnd) > 0
        AND web100_log_entry.snap.CountRTT > 0
        AND web100_log_entry.snap.HCThruOctetsReceived  > 0
        AND web100_log_entry.snap.HCThruOctetsAcked > 0
)
GROUP BY
    machine
ORDER BY
    machine
