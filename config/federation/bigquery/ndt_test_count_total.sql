-- ndt_test_count_total counts the total number of NDT test (up & down) over the
-- history of the project. The constant was taken from the legacy tables.
#standardSQL
SELECT
    828544145 + count(test_id) as value
FROM
    `measurement-lab.public.ndt`
WHERE
    -- Ignore tests from eb.measurementlab.net
    connection_spec.client_ip != '45.56.98.222'
AND
    log_time > TIMESTAMP("2017-05-01")
