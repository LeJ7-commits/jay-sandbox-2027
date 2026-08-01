select
    i.impression_date,
    i.placement,
    i.market,
    i.impressions,
    a.total_avails,
    round(i.impressions::numeric / a.total_avails, 4) as fill_rate,
    round(i.avg_cpm, 2) as avg_cpm
from {{ ref('int_daily_impressions') }} i
join {{ ref('stg_ad_avails_bulk') }} a
    on a.avail_date = i.impression_date
   and a.placement = i.placement
   and a.market = i.market
