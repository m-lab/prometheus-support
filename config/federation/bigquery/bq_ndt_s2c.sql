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
  -- and parsed) we should wait 42 hours after start of a given day.
  -- The following is equivalent to the pseudo code:
  --     date(now() - 18h) - 1d
CREATE TEMPORARY FUNCTION
  queryDATE() AS ( DATE( TIMESTAMP_SUB( TIMESTAMP_TRUNC( TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 18 HOUR), DAY), INTERVAL 24 HOUR ) ) );
  -- Takes ParseInfo.TaskFileName and returns an M-Lab hostname.
CREATE TEMPORARY FUNCTION
  toNodeName(tfn STRING) AS ( CONCAT( REGEXP_EXTRACT(tfn, r'(mlab[1-4])-[a-z]{3}[0-9]{2}.*'), "-", REGEXP_EXTRACT(tfn, r'mlab[1-4]-([a-z]{3}[0-9]{2}).*') ) );
WITH
  disco_intervals_with_discards AS (
  SELECT
    toNodeName(hostname) AS node,
    TIMESTAMP_SUB(sample.timestamp, INTERVAL 10 SECOND) AS tstart,
    sample.timestamp AS tend,
    sample.value AS discards
  FROM
    `measurement-lab.utilization.switch`,
    UNNEST(sample) AS sample
  WHERE
    partition_date = queryDATE()
    AND metric = 'switch.discards.uplink.tx'
  GROUP BY
    hostname,
    tstart,
    tend,
    discards
  HAVING
    discards > 0 ),
  ndt_s2c_tests AS (
  SELECT
    toNodeName(ParseInfo.TaskFileName) AS node,
    result.S2C.UUID AS s2c_uuid,
    result.S2C.StartTime AS tstart,
    result.S2C.EndTime AS tend
  FROM
    `measurement-lab.ndt.ndt5`
  WHERE
    partition_date = queryDATE()
    AND result.S2C.UUID IS NOT NULL
    AND result.S2C.UUID != "ERROR_DISCOVERING_UUID"
  GROUP BY
    node,
    s2c_uuid,
    tstart,
    tend
  UNION ALL
  SELECT
    CONCAT(server.Machine, "-", server.Site) AS node,
    raw.Download.UUID AS s2c_uuid,
    raw.Download.StartTime AS tstart,
    raw.Download.EndTime AS tend
  FROM
    `measurement-lab.ndt.ndt7`
  WHERE
    date = queryDATE()
    AND raw.Download.UUID IS NOT NULL
    AND raw.Download.UUID != "ERROR_DISCOVERING_UUID"
  GROUP BY
    node,
    s2c_uuid,
    tstart,
    tend ),
  ndt_s2c_tests_with_discards AS (
  SELECT
    ndt_s2c_tests.s2c_uuid AS s2c_uuid,
    SUM(disco_intervals_with_discards.discards) AS discards
  FROM
    disco_intervals_with_discards
  JOIN
    ndt_s2c_tests
  ON
    (ndt_s2c_tests.node = disco_intervals_with_discards.node
      AND (disco_intervals_with_discards.tstart = ndt_s2c_tests.tstart
        OR ndt_s2c_tests.tstart BETWEEN disco_intervals_with_discards.tstart
        AND disco_intervals_with_discards.tend
        OR disco_intervals_with_discards.tend = ndt_s2c_tests.tend
        OR ndt_s2c_tests.tend BETWEEN disco_intervals_with_discards.tstart
        AND disco_intervals_with_discards.tend))
  GROUP BY
    s2c_uuid )
SELECT
  metro,
  site,
  node,
  COUNTIF(discards = 'true') AS value_with_discards,
  COUNT(*) AS value_total
FROM (
  SELECT
    result.S2C.UUID AS s2c_uuid,
    REGEXP_EXTRACT(ParseInfo.TaskFileName, r'mlab[1-4]-([a-z]{3})[0-9]{2}.*') AS metro,
    REGEXP_EXTRACT(ParseInfo.TaskFileName, r'mlab[1-4]-([a-z]{3}[0-9]{2}).*') AS site,
    toNodeName(ParseInfo.TaskFileName) AS node,
    CASE
      WHEN result.S2C.UUID IN ( SELECT s2c_uuid FROM ndt_s2c_tests_with_discards) THEN 'true'
    ELSE
    'false'
  END
    AS discards
  FROM
    `measurement-lab.ndt.ndt5`
  WHERE
    partition_date = queryDATE()
    AND result.S2C.UUID IS NOT NULL
    AND result.S2C.UUID != "ERROR_DISCOVERING_UUID"
  UNION ALL
  SELECT
    raw.Download.UUID AS s2c_uuid,
    REGEXP_EXTRACT(server.Site, r'([a-z]{3})[0-9]{2}') AS metro,
    server.Site AS site,
    CONCAT(server.Machine, "-", server.Site) AS node,
    CASE
      WHEN raw.Download.UUID IN ( SELECT s2c_uuid FROM ndt_s2c_tests_with_discards) THEN 'true'
    ELSE
    'false'
  END
    AS discards
  FROM
    `measurement-lab.ndt.ndt7`
  WHERE
    date = queryDATE()
    AND raw.Download.UUID IS NOT NULL
    AND raw.Download.UUID != "ERROR_DISCOVERING_UUID")
GROUP BY
  metro,
  site,
  node
ORDER BY
  metro,
  site,
  node
