#standardSQL
-- bq_ndt_metrics calculates the daily median rtt AS well AS avg and median
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

        -- Download AS bits-per-second
        8 * 1000000 * (web100_log_entry.snap.HCThruOctetsAcked /
              (web100_log_entry.snap.SndLimTimeRwin +
                    web100_log_entry.snap.SndLimTimeCwnd +
                        web100_log_entry.snap.SndLimTimeSnd)) AS download,

        -- Upload AS bits-per-second
        8 * 1000000 * (web100_log_entry.snap.HCThruOctetsReceived /
              web100_log_entry.snap.Duration) AS upload,

        -- Average RTT AS seconds
        web100_log_entry.snap.SumRTT/web100_log_entry.snap.CountRTT/1000 AS rtt

    FROM
       `measurement-lab.public.ndt`

    WHERE
        -- NOTE: to guarantee the _PARTITIONTIME data is up to date we should
        -- wait 36hours. So, this query should be run either at the end of the
        -- following day, or more often (e.g. hourly) so future queries see all
        -- data.
        _PARTITIONTIME = TIMESTAMP_SUB(TIMESTAMP_TRUNC(TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 12 HOUR), DAY), INTERVAL 24 HOUR)

    -- Basic test quality filters for safe division.
    AND web100_log_entry.snap.Duration > 0
    AND (web100_log_entry.snap.SndLimTimeRwin + web100_log_entry.snap.SndLimTimeCwnd + web100_log_entry.snap.SndLimTimeSnd) > 0
    AND web100_log_entry.snap.CountRTT > 0
)
GROUP BY
    machine

ORDER BY
    machine
