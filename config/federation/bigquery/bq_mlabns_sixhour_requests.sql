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
  AND protoPayload.ip IN ( SELECT ip FROM `mlab-ns.library.six_hour_ips_20190331` )
GROUP BY
  resource
