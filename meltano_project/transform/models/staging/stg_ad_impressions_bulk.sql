select
    impression_id,
    placement,
    market,
    cpm,
    impression_ts,
    impression_ts::date as impression_date
from {{ source('raw_warmup', 'ad_impressions_bulk') }}
