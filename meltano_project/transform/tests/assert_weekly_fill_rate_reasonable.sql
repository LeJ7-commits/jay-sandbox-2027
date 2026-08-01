-- singular test: fails (returns rows) if weekly fill_rate falls outside a sane 0-1.5 range
-- (some overdelivery is expected, but anything past 1.5x avails signals broken data)
select *
from {{ ref('fct_weekly_fill_rate_by_market') }}
where fill_rate < 0 or fill_rate > 1.5
