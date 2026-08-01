with weekly_impressions as (
    select
        market,
        extract(isoyear from impression_date)::int as iso_year,
        extract(week from impression_date)::int as iso_week,
        date_trunc('week', impression_date)::date as week_start_date,
        sum(impressions) as total_impressions
    from {{ ref('int_daily_impressions') }}
    group by 1, 2, 3, 4
),

weekly_avails as (
    select
        market,
        extract(isoyear from avail_date)::int as iso_year,
        extract(week from avail_date)::int as iso_week,
        sum(total_avails) as total_avails
    from {{ ref('stg_ad_avails_bulk') }}
    group by 1, 2, 3
)

select
    i.market,
    i.iso_year,
    i.iso_week,
    i.week_start_date,
    i.total_impressions,
    a.total_avails,
    round(i.total_impressions::numeric / a.total_avails, 4) as fill_rate
from weekly_impressions i
join weekly_avails a
    on a.market = i.market
   and a.iso_year = i.iso_year
   and a.iso_week = i.iso_week
