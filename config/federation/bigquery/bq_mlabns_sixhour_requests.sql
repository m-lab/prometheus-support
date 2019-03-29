WITH
  clientsInSixHourPeriods AS (
    SELECT
      protoPayload.ip as ip,
      protoPayload.resource as resource,
      COUNT(*) AS requestsPerDay,
      CASE
        WHEN protoPayload.startTime BETWEEN TIMESTAMP_ADD(TIMESTAMP_TRUNC(protoPayload.startTime, DAY), INTERVAL 19 MINUTE) AND TIMESTAMP_ADD(TIMESTAMP_TRUNC(protoPayload.startTime, DAY), INTERVAL 81 MINUTE) THEN 1
        WHEN protoPayload.startTime BETWEEN TIMESTAMP_ADD(TIMESTAMP_TRUNC(protoPayload.startTime, DAY), INTERVAL 379 MINUTE) AND TIMESTAMP_ADD(TIMESTAMP_TRUNC(protoPayload.startTime, DAY), INTERVAL 441 MINUTE) THEN 2
        WHEN protoPayload.startTime BETWEEN TIMESTAMP_ADD(TIMESTAMP_TRUNC(protoPayload.startTime, DAY), INTERVAL 739 MINUTE) AND TIMESTAMP_ADD(TIMESTAMP_TRUNC(protoPayload.startTime, DAY), INTERVAL 801 MINUTE) THEN 4
        WHEN protoPayload.startTime BETWEEN TIMESTAMP_ADD(TIMESTAMP_TRUNC(protoPayload.startTime, DAY), INTERVAL 1099 MINUTE) AND TIMESTAMP_ADD(TIMESTAMP_TRUNC(protoPayload.startTime, DAY), INTERVAL 1161 MINUTE) THEN 8
        ELSE 0
      END AS period
    FROM
  `mlab-ns.exports.appengine_googleapis_com_request_log_*`
    WHERE
         (_table_suffix = FORMAT_DATE("%Y%m%d", CURRENT_DATE())
      OR  _table_suffix = FORMAT_DATE("%Y%m%d", DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))
      OR  _table_suffix = FORMAT_DATE("%Y%m%d", DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY))
      AND protoPayload.starttime > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 DAY))
      AND (protoPayload.resource = '/neubot' OR protoPayload.resource = '/ndt')
      AND protoPayload.userAgent is NULL
    GROUP BY
      -- Also group by 'period' to guarantee that we only have one representative
      -- request from each ip and resource.
      ip, resource, period
  ),
  clientsOutsideSixHourPeriods AS (
    SELECT
      protoPayload.ip as ip
    FROM
  `mlab-ns.exports.appengine_googleapis_com_request_log_*`
    WHERE
         (_table_suffix = FORMAT_DATE("%Y%m%d", CURRENT_DATE())
      OR  _table_suffix = FORMAT_DATE("%Y%m%d", DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))
      OR  _table_suffix = FORMAT_DATE("%Y%m%d", DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY))
      AND protoPayload.starttime > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 DAY))
      AND (protoPayload.resource = '/neubot' OR protoPayload.resource = '/ndt')
      AND protoPayload.userAgent is NULL
      AND (
          protoPayload.startTime BETWEEN TIMESTAMP_ADD(TIMESTAMP_TRUNC(protoPayload.startTime, DAY), INTERVAL 0 MINUTE) AND TIMESTAMP_ADD(TIMESTAMP_TRUNC(protoPayload.startTime, DAY), INTERVAL 19 MINUTE) OR
          protoPayload.startTime BETWEEN TIMESTAMP_ADD(TIMESTAMP_TRUNC(protoPayload.startTime, DAY), INTERVAL 81 MINUTE) AND TIMESTAMP_ADD(TIMESTAMP_TRUNC(protoPayload.startTime, DAY), INTERVAL 379 MINUTE) OR
          protoPayload.startTime BETWEEN TIMESTAMP_ADD(TIMESTAMP_TRUNC(protoPayload.startTime, DAY), INTERVAL 441 MINUTE) AND TIMESTAMP_ADD(TIMESTAMP_TRUNC(protoPayload.startTime, DAY), INTERVAL 739 MINUTE) OR
          protoPayload.startTime BETWEEN TIMESTAMP_ADD(TIMESTAMP_TRUNC(protoPayload.startTime, DAY), INTERVAL 801 MINUTE) AND TIMESTAMP_ADD(TIMESTAMP_TRUNC(protoPayload.startTime, DAY), INTERVAL 1099 MINUTE) OR
          protoPayload.startTime BETWEEN TIMESTAMP_ADD(TIMESTAMP_TRUNC(protoPayload.startTime, DAY), INTERVAL 1161 MINUTE) AND TIMESTAMP_ADD(TIMESTAMP_TRUNC(protoPayload.startTime, DAY), INTERVAL 1440 MINUTE)
      )
    GROUP BY
      ip
  ),
  nsRequestsInSixHourPeriods AS (
    SELECT
      ip, resource, SUM(period) as total
    FROM
      clientsInSixHourPeriods
    GROUP BY
      ip, resource
    HAVING
      -- Guarantee that each client runs in each period by totaling the 'period'
      -- values. If all periods are represented, then the sum(1 + 2 + 4 + 8) = 15.
      total = 15
  ),
  uniqueIPsInSixHourPeriods AS (
    (SELECT ip FROM nsRequestsInSixHourPeriods WHERE resource = "/neubot" AND ip NOT IN ( SELECT ip FROM clientsOutsideSixHourPeriods )
     intersect DISTINCT
     SELECT ip FROM nsRequestsInSixHourPeriods WHERE resource = "/ndt" AND ip NOT IN ( SELECT ip FROM clientsOutsideSixHourPeriods ))
  )

SELECT
    protoPayload.resource as resource,
    COUNT(*) as value
FROM
   `mlab-ns.exports.appengine_googleapis_com_request_log_*`
WHERE
     (_table_suffix = FORMAT_DATE("%Y%m%d", CURRENT_DATE())
  OR  _table_suffix = FORMAT_DATE("%Y%m%d", DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)))
  AND protoPayload.starttime > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 15 MINUTE)
  AND protoPayload.starttime <= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 10 MINUTE)
  AND (protoPayload.resource = '/neubot' OR protoPayload.resource = '/ndt')
  AND protoPayload.userAgent IS NULL
  AND protoPayload.ip IN ( SELECT ip FROM uniqueIPsInSixHourPeriods )
GROUP BY
  resource
