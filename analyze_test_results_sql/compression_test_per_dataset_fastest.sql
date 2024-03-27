-- speed
select distinct on (dataset_name)
  dataset_name,
  method,
  level,
  time_spent_s,
  (select (avg(test_value)/1000)::numeric(7,1) from dataset_test_results where dataset_name = x.dataset_name) as avg_time_spent_s,
  backup_size,
  (select pg_size_pretty(avg(test_value_2)) from dataset_test_results where dataset_name = x.dataset_name) as avg_backup_size
from (
  select
    dataset_name,
    method,
    level,
    (time_spent_ms/1000)::numeric(7,1) as time_spent_s,
    pg_size_pretty(backup_size_b) as backup_size
  from (
      select
        dataset_name,
        test_id method,
        test_id_num as level,
        avg(test_value) as time_spent_ms,
        avg(test_value_2) as backup_size_b
      from
        dataset_test_results
      group by -- take avg of multiple runs of one test configuration
        1, 2, 3
    ) avg_of_runs
) x
order by dataset_name, time_spent_s;