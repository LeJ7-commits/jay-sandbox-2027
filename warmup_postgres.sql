-- 1. Large synthetic impressions table (~3M rows, 60 days, 3 placements, 4 markets)
DROP TABLE IF EXISTS raw.ad_impressions_bulk;
CREATE TABLE raw.ad_impressions_bulk (
    impression_id bigint,
    placement     text,
    market        text,
    cpm           numeric(10,2),
    impression_ts timestamp
);

INSERT INTO raw.ad_impressions_bulk (impression_id, placement, market, cpm, impression_ts)
SELECT
    gs,
    (ARRAY['pre-roll','mid-roll','post-roll'])[1 + floor(random()*3)::int],
    (ARRAY['SE','NO','DK','FI'])[1 + floor(random()*4)::int],
    round((20 + random()*60)::numeric, 2),
    timestamp '2026-01-01' + (random() * interval '59 days') + (random() * interval '24 hours')
FROM generate_series(1, 3000000) AS gs;

CREATE INDEX ON raw.ad_impressions_bulk (impression_ts);
ANALYZE raw.ad_impressions_bulk;

-- 2. Synthetic daily avails/capacity table — small, one row per day/placement/market
DROP TABLE IF EXISTS raw.ad_avails_bulk;
CREATE TABLE raw.ad_avails_bulk (
    avail_date   date,
    placement    text,
    market       text,
    total_avails int
);

INSERT INTO raw.ad_avails_bulk (avail_date, placement, market, total_avails)
SELECT
    d::date, p, m,
    30000 + floor(random()*20000)::int
FROM generate_series('2026-01-01'::date, '2026-03-01'::date, interval '1 day') AS d
CROSS JOIN (VALUES ('pre-roll'),('mid-roll'),('post-roll')) AS placements(p)
CROSS JOIN (VALUES ('SE'),('NO'),('DK'),('FI')) AS markets(m);

-- 3. Daily fill rate, with window functions: 7-day moving avg, day-over-day change, same-day rank
WITH daily_impressions AS (
    SELECT impression_ts::date AS impression_date, placement, market,
           count(*) AS impressions, avg(cpm) AS avg_cpm
    FROM raw.ad_impressions_bulk
    GROUP BY 1,2,3
),
fill_rate AS (
    SELECT di.impression_date, di.placement, di.market, di.impressions,
           av.total_avails,
           round(di.impressions::numeric / av.total_avails, 4) AS fill_rate,
           di.avg_cpm
    FROM daily_impressions di
    JOIN raw.ad_avails_bulk av
      ON av.avail_date = di.impression_date
     AND av.placement = di.placement
     AND av.market = di.market
)
SELECT impression_date, placement, market, fill_rate,
    round(avg(fill_rate) OVER (
        PARTITION BY placement, market ORDER BY impression_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 4) AS fill_rate_7d_avg,
    round(fill_rate - LAG(fill_rate) OVER (
        PARTITION BY placement, market ORDER BY impression_date), 4) AS fill_rate_dod_change,
    RANK() OVER (PARTITION BY impression_date ORDER BY fill_rate DESC) AS fill_rate_rank_that_day
FROM fill_rate
ORDER BY impression_date, placement, market
LIMIT 50;

-- 4. Partitioned version of the same impressions table, partitioned by day
DROP TABLE IF EXISTS raw.ad_impressions_bulk_partitioned;
CREATE TABLE raw.ad_impressions_bulk_partitioned (
    impression_id bigint, placement text, market text, cpm numeric(10,2), impression_ts timestamp
) PARTITION BY RANGE (impression_ts);

DO $$
DECLARE d date;
BEGIN
    FOR d IN SELECT generate_series('2026-01-01'::date, '2026-03-01'::date, interval '1 day')::date
    LOOP
        EXECUTE format(
            'CREATE TABLE raw.ad_impressions_bulk_p_%s PARTITION OF raw.ad_impressions_bulk_partitioned
             FOR VALUES FROM (%L) TO (%L)',
            to_char(d, 'YYYYMMDD'), d, d + 1
        );
    END LOOP;
END $$;

INSERT INTO raw.ad_impressions_bulk_partitioned SELECT * FROM raw.ad_impressions_bulk;
CREATE INDEX ON raw.ad_impressions_bulk_partitioned (impression_ts);
ANALYZE raw.ad_impressions_bulk_partitioned;

-- 5. Compare query plans: same single-day query, flat table vs. partitioned
EXPLAIN ANALYZE
SELECT count(*), avg(cpm) FROM raw.ad_impressions_bulk
WHERE impression_ts >= '2026-02-15' AND impression_ts < '2026-02-16';

EXPLAIN ANALYZE
SELECT count(*), avg(cpm) FROM raw.ad_impressions_bulk_partitioned
WHERE impression_ts >= '2026-02-15' AND impression_ts < '2026-02-16';