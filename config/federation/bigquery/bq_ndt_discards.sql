#standardSQL
-- bq_ndt_discards returns the number NDT S2C tests with a time window that
-- overlaps with a switch utilization time windows in which there were a
-- non-zero number of uplink discards measured. DISCO polls switch SNMP data
-- every 10s. For every 10s SNMP data polling interval, if discards were
-- observed, then this query looks for all NDT S2C test with a start or end
-- time equivalent to the start or end time of the SNMP polling interval, or an
-- NDT S2C start or end time that falls within the SNMP polling interval.

-- For faster queries we use `partition_date` boundaries. And, to
-- guarantee the partition_date data is "complete" (all data collected
-- and parsed) we should wait 36 hours after start of a given day.
-- The following is equivalent to the pseudo code:
--     date(now() - 12h) - 1d
DECLARE partitiondate DATE DEFAULT DATE(TIMESTAMP_SUB(TIMESTAMP_TRUNC(TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 12 HOUR), DAY), INTERVAL 24 HOUR));

WITH
  ndt_test_ids_with_discards AS (
  SELECT
    ndt.s2c_uuid AS s2c_uuid,
    SUM(disco.discards) AS discards
  FROM (
    SELECT
      hostname AS node,
      TIMESTAMP_SUB(sample.timestamp, INTERVAL 10 SECOND) AS tstart,
      sample.timestamp AS tend,
      sample.value AS discards
    FROM
      `measurement-lab.utilization.switch`,
      UNNEST(sample) AS sample
    WHERE
      partition_date = partitiondate
      AND metric = 'switch.discards.uplink.tx'
    GROUP BY
      hostname,
      tstart,
      tend,
      discards
    HAVING
      discards > 0 ) AS disco
  JOIN (
    SELECT
      CONCAT(REGEXP_EXTRACT(ParseInfo.TaskFileName, r'(mlab[1-4])-[a-z]{3}[0-9]{2}.*'), ".", REGEXP_EXTRACT(ParseInfo.TaskFileName, r'mlab[1-4]-([a-z]{3}[0-9]{2}).*'), ".measurement-lab.org") AS node,
      result.S2C.UUID AS s2c_uuid,
      result.S2C.StartTime AS tstart,
      result.S2C.EndTime AS tend
    FROM
      `measurement-lab.ndt.ndt5`
    WHERE
      partition_date = partitiondate
      AND result.S2C.UUID IS NOT NULL
      AND result.S2C.UUID != "ERROR_DISCOVERING_UUID"
    GROUP BY
      node,
      s2c_uuid,
      tstart,
      tend ) AS ndt
  ON
    (ndt.node = disco.node
      AND (disco.tstart = ndt.tstart
        OR ndt.tstart BETWEEN disco.tstart
        AND disco.tend
        OR disco.tend = ndt.tend
        OR ndt.tend BETWEEN disco.tstart
        AND disco.tend))
  GROUP BY
    s2c_uuid )
SELECT
  metro,
  site,
  node,
  COUNT(*) AS value
FROM (
  SELECT
    result.S2C.UUID AS s2c_uuid,
    REGEXP_EXTRACT(ParseInfo.TaskFileName, r'mlab[1-4]-([a-z]{3})[0-9]{2}.*') AS metro,
    REGEXP_EXTRACT(ParseInfo.TaskFileName, r'mlab[1-4]-([a-z]{3}[0-9]{2}).*') AS site,
    CONCAT(REGEXP_EXTRACT(ParseInfo.TaskFileName, r'(mlab[1-4])-[a-z]{3}[0-9]{2}.*'), ".", REGEXP_EXTRACT(ParseInfo.TaskFileName, r'mlab[1-4]-([a-z]{3}[0-9]{2}).*'), ".measurement-lab.org") AS node,
    CASE
      WHEN result.S2C.UUID IN (SELECT s2c_uuid FROM ndt_test_ids_with_discards) THEN 'non-zero'
      ELSE 'zero'
    END AS discards
  FROM
    `measurement-lab.ndt.ndt5`
  WHERE
    partition_date = partitiondate
    AND result.S2C.UUID IS NOT NULL
    AND result.S2C.UUID != "ERROR_DISCOVERING_UUID")
WHERE
  discards = 'non-zero'
GROUP BY
  metro,
  site,
  node,
  discards
ORDER BY
  metro,
  site,
  node
