-- ===============================================
-- CMPU4003_01_relational_schema.sql : OLTP EVENTS
-- ===============================================
-- -----------------------------------------------
-- Generate synthetic customer events
-- -----------------------------------------------
-- -----------------------------------------------
-- Generate realistic synthetic customer events
-- -----------------------------------------------
-- About 3–6 events per customer on average
-- Distribution over the past 60 days
-- Event types and pages mimic real browsing behaviour
-- -----------------------------------------------

INSERT INTO rel_src.events (customer_id, event_ts, event_type, payload)
SELECT
  c.customer_id,
  -- Spread events across past 60 days
  now() - (random() * '60 days'::interval) AS event_ts,
  -- Random event type
  (ARRAY[
    'page_view',
    'search',
    'add_to_cart',
    'checkout',
    'purchase',
    'logout'
  ])[1 + (random() * 5)::int] AS event_type,
  -- Structured JSON payload
  jsonb_build_object(
    'page', (ARRAY[
      '/home',
      '/products',
      '/products/electronics',
      '/products/fashion',
      '/cart',
      '/checkout'
    ])[1 + (random() * 5)::int],
    'device', (ARRAY['mobile', 'desktop', 'tablet'])[1 + (random() * 2)::int],
    'ref', (ARRAY['email', 'social', 'direct', 'search'])[1 + (random() * 3)::int],
    'geo', jsonb_build_object(
      'lat', 53.0 + random() * 5,
      'lon', -6.0 - random() * 5
    ),
    'session_duration_sec', (random() * 600)::int
  )
FROM rel_src.customers c,
     generate_series(1, (3 + (random() * 3)::int)) gs;  -- 3–6 events per customer

ANALYZE rel_src.events;

