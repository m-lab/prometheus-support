SELECT COUNT(*) as value
FROM `mlab-ns.exports.appengine_googleapis_com_request_log_*` as t, 
      t.protoPayload.line AS x
WHERE 
  (_table_suffix = FORMAT_DATE("%Y%m%d", CURRENT_DATE())
  OR  _table_suffix = FORMAT_DATE("%Y%m%d", DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)))
  AND t.protoPayload.starttime > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 15 MINUTE)
  AND t.protoPayload.starttime <= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 10 MINUTE)
  AND STARTS_WITH(x.logMessage, 'SIGNATURE_FOUND')
