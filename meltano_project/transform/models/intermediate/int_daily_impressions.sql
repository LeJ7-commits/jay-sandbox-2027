select
    impression_date,
    placement,
    market,
    count(*) as impressions,
    avg(cpm) as avg_cpm
from {{ ref('stg_ad_impressions_bulk') }}
group by 1, 2, 3
