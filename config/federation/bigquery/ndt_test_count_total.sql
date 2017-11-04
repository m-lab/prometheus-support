SELECT
    828544145 + count(test_id) as value
FROM
    [measurement-lab:public.ndt]
WHERE
    connection_spec.client_ip != '45.56.98.222'
AND log_time > TIMESTAMP("2017-05-01")
