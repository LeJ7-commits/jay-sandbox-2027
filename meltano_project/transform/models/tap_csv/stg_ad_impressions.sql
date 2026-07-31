select impression_id, placement, market, cpm::numeric as cpm, ts::date as impression_date
from {{ source('tap_csv', 'ad_impressions') }}
