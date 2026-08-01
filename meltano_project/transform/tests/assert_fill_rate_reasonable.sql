-- singular test: fails (returns rows) if fill_rate falls outside a sane 0-1 range
select *
from {{ ref('fct_fill_rate_by_placement') }}
where fill_rate < 0 or fill_rate > 1
