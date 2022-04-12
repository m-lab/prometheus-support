--
-- bq_daily_discuss.sql is designed to be part of a system that simulates
-- user-privileged queries. By running with the same privileges as users, we will
-- be able to monitor user-visible failures, such as permission errors or schema
-- changes.
--
-- To achive this, we run bigquery exporter with service account credentials. The
-- service account is created without any role/permissions. So, the only
-- permissions granted are through the discuss@ ACL, just like users.
--
-- TODO(github.com/m-lab/prometheus-support/issues/894): include discuss@
-- authenticated queries of unified views once they are more efficient.

WITH ndt7 AS (
    SELECT * FROM `measurement-lab.ndt.ndt7` WHERE date > DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)
), ndt5 AS (
    SELECT * FROM `measurement-lab.ndt.ndt5` WHERE date > DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)
), scamper1 AS (
    SELECT * FROM `measurement-lab.ndt.scamper1` WHERE date > DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)
), tcpinfo AS (
    SELECT * FROM `measurement-lab.ndt.tcpinfo` WHERE date > DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)
)

SELECT "ndt7" as datatype, COUNT(*) AS value_total FROM ndt7
UNION ALL
SELECT "ndt5" as datatype, COUNT(*) AS value_total FROM ndt5
UNION ALL
SELECT "scamper1" as datatype, COUNT(*) AS value_total FROM scamper1
UNION ALL
SELECT "tcpinfo" as datatype, COUNT(*) AS value_total FROM tcpinfo
