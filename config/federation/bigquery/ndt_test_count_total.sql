-- ndt_test_count_total counts the total number of NDT test (up & down) over the
-- history of the project. The constant was taken from the legacy tables.
#standardSQL
-- Number of rows without duplicates
SELECT
  828544145 + count(test_id) as value
FROM (
  SELECT
    test_id,
    ROW_NUMBER() OVER (PARTITION BY test_id) row_number
  FROM
    -- Use ndt_fast, which excludes rows from EB
    `measurement-lab.public.ndt_fast`
  WHERE
    partition_date >= DATE('2017-05-01')
)
WHERE
  row_number = 1
