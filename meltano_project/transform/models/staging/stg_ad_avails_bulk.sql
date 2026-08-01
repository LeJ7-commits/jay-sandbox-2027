select
    avail_date,
    placement,
    market,
    total_avails
from {{ source('raw_warmup', 'ad_avails_bulk') }}
