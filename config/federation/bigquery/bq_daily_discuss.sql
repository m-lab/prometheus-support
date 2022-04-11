--
-- bq_daily_discuss.sql should be run with a service account authorized to query
-- measurement-lab tables through the discuss@ mailing list.
--
-- Because this requires separate service account credentials,
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
