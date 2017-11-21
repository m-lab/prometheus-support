-- bq_ndt_metrics calculates the daily median rtt as well as avg and median
-- upload and download rates per machine. These values can help recognize major
-- performance regressions of servers or kernels.
--
-- Note: this query returns multiple values. So, resulting metrics will be:
--   bq_ndt_server_tests
--   bq_ndt_server_download_avg_rate
--   bq_ndt_server_download_median_rate
--   bq_ndt_server_download_median_rtt
--   bq_ndt_server_upload_avg_rate
--   bq_ndt_server_upload_median_rate
--   bq_ndt_server_upload_median_rtt
#standardSQL

SELECT
    machine,
    AVG(IF(direction = "s2c", download, NULL)) AS value_download_avg_rate,
    AVG(IF(direction = "c2s", upload, NULL)) AS value_upload_avg_rate,
    APPROX_QUANTILES(IF(direction = "s2c", download, NULL), 2)[OFFSET(1)] as value_download_median_rate,
    APPROX_QUANTILES(IF(direction = "c2s", upload, NULL), 2)[OFFSET(1)] as value_upload_median_rate,
    APPROX_QUANTILES(IF(direction = "s2c", rtt, NULL), 2)[OFFSET(1)] as value_download_median_rtt,
    APPROX_QUANTILES(IF(direction = "c2s", rtt, NULL), 2)[OFFSET(1)] as value_upload_median_rtt,
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
          END as direction,

        -- Download as bits-per-second
        8 * 1000000 * (web100_log_entry.snap.HCThruOctetsAcked /
              (web100_log_entry.snap.SndLimTimeRwin +
                    web100_log_entry.snap.SndLimTimeCwnd +
                        web100_log_entry.snap.SndLimTimeSnd)) AS download,

        -- Upload as bits-per-second
        8 * 1000000 * (web100_log_entry.snap.HCThruOctetsReceived /
              web100_log_entry.snap.Duration) as upload,

        -- Average RTT as seconds
        web100_log_entry.snap.SumRTT/web100_log_entry.snap.CountRTT/1000 as rtt

    FROM
       `measurement-lab.public.ndt`

    WHERE
        -- NOTE: to guarantee the _PARTITIONTIME data is up to date we should
        -- wait 36hours. So, this query should be run either at the end of the
        -- following day, or more often (e.g. hourly) so future queries see all
        -- data.
        _PARTITIONTIME = TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))

    -- Basic test quality filters for safe division.
    AND web100_log_entry.snap.Duration > 0
    AND (web100_log_entry.snap.SndLimTimeRwin + web100_log_entry.snap.SndLimTimeCwnd + web100_log_entry.snap.SndLimTimeSnd) > 0
    AND web100_log_entry.snap.CountRTT > 0
)
GROUP BY
    machine

ORDER BY
    machine
