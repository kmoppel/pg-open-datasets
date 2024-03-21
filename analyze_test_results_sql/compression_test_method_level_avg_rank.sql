-- rank
with q_data as (
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
), q_dataset_mins as (
    select
      dataset_name,
      min(time_spent_ms) min_time_spent_ms,
      min(backup_size_b) min_backup_size_b
    from
      q_data
    group by
      1
)
select
  method,
  level,
  avg(rank)::numeric(3,1) as avg_per_dataset_rank
from (
select
  *,
  rank() over(partition by dataset_name order by score)
from (
select
  *,
  (time_score + size_score)::numeric(6,2) as score
from (
select
    q_data.dataset_name,
    method,
    level,
    time_spent_ms,
    (time_spent_ms / min_time_spent_ms)::numeric(6,2) as time_score,
    backup_size_b,
    (backup_size_b / min_backup_size_b)::numeric(6,2) as size_score
from
  q_data
  join
  q_dataset_mins using (dataset_name)
) x
order by
  dataset_name, time_score + size_score
) y
) z
group by 1, 2
order by 3
;