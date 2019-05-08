#standardSQL
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

SELECT
    machine,
    APPROX_QUANTILES(IF(direction = "s2c", download, NULL), 2)[OFFSET(1)] AS value_download_median_rate,
    APPROX_QUANTILES(IF(direction = "c2s", upload, NULL), 2)[OFFSET(1)] AS value_upload_median_rate,
    APPROX_QUANTILES(IF(direction = "s2c", rtt, NULL), 2)[OFFSET(1)] AS value_download_median_rtt,
    APPROX_QUANTILES(IF(direction = "c2s", rtt, NULL), 2)[OFFSET(1)] AS value_upload_median_rtt,
    -- TODO: evaluate utility of avg data.
    AVG(IF(direction = "s2c", download, NULL)) AS value_download_avg_rate,
    AVG(IF(direction = "c2s", upload, NULL)) AS value_upload_avg_rate,
    -- TODO: evaluate utility of percentile data.
    APPROX_QUANTILES(IF(direction = "s2c", download, NULL), 100)[OFFSET(99)] AS value_download_99th_rate,
    APPROX_QUANTILES(IF(direction = "s2c", download, NULL), 1000)[OFFSET(999)] AS value_download_999th_rate,
    APPROX_QUANTILES(IF(direction = "c2s", upload, NULL), 100)[OFFSET(99)] AS value_upload_99th_rate,
    APPROX_QUANTILES(IF(direction = "c2s", upload, NULL), 1000)[OFFSET(999)] AS value_upload_99_9th_rate,
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

        -- Average RTT as seconds
        web100_log_entry.snap.SumRTT/web100_log_entry.snap.CountRTT/1000 AS rtt

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
)
GROUP BY
    machine

ORDER BY
    machine
