-- ===============================================
-- CMPU4003_01_relational_schema.sql : OLTP Relational schema
-- ===============================================

DROP SCHEMA IF EXISTS rel_src CASCADE;

CREATE SCHEMA rel_src;
SET search_path = rel_src, public;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- -----------------------------------------------
-- Reference tables
-- -----------------------------------------------
CREATE TABLE rel_src.regions (
  region_id   smallserial PRIMARY KEY,
  region_code text UNIQUE NOT NULL,
  region_name text NOT NULL
);

CREATE TABLE rel_src.categories (
  category_id serial PRIMARY KEY,
  parent_id   int REFERENCES rel_src.categories(category_id) ON DELETE SET NULL,
  category_name text NOT NULL
);

-- -----------------------------------------------
-- Core entities
-- -----------------------------------------------
CREATE TABLE rel_src.customers (
  customer_id bigserial PRIMARY KEY,
  region_id   smallint NOT NULL REFERENCES rel_src.regions(region_id),
  full_name   text NOT NULL,
  email       text UNIQUE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  attributes  jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE rel_src.merchants (
  merchant_id bigserial PRIMARY KEY,
  merchant_name text NOT NULL,
  region_id   smallint NOT NULL REFERENCES rel_src.regions(region_id)
);

CREATE TABLE rel_src.products (
  product_id   bigserial PRIMARY KEY,
  category_id  int REFERENCES rel_src.categories(category_id),
  merchant_id  bigint REFERENCES rel_src.merchants(merchant_id),
  sku          text UNIQUE NOT NULL,
  product_name text NOT NULL,
  base_price   numeric(12,2) NOT NULL,
  attributes   jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- -----------------------------------------------
-- Orders and items
-- -----------------------------------------------
CREATE TABLE rel_src.orders (
  order_id     bigserial PRIMARY KEY,
  customer_id  bigint NOT NULL REFERENCES rel_src.customers(customer_id),
  merchant_id  bigint NOT NULL REFERENCES rel_src.merchants(merchant_id),
  order_ts     timestamptz NOT NULL,
  order_date   date,
  status       text NOT NULL,
  total_amount numeric(14,2) NOT NULL,
  meta         jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- Function with associated trigger to automatically set the order date
CREATE FUNCTION rel_src.set_order_date() RETURNS trigger AS $$
BEGIN
  NEW.order_date := (NEW.order_ts AT TIME ZONE 'UTC')::date;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_set_order_date
BEFORE INSERT OR UPDATE ON rel_src.orders
FOR EACH ROW
EXECUTE FUNCTION rel_src.set_order_date();

CREATE TABLE rel_src.order_items (
  order_id   bigint NOT NULL REFERENCES rel_src.orders(order_id) ON DELETE CASCADE,
  item_no    int NOT NULL,
  product_id bigint NOT NULL REFERENCES rel_src.products(product_id),
  quantity   int NOT NULL,
  unit_price numeric(12,2) NOT NULL,
  discount   numeric(12,2) NOT NULL DEFAULT 0,
  PRIMARY KEY (order_id, item_no)
);

-- -----------------------------------------------
-- Customer activity events (behavioural data)
-- -----------------------------------------------
-- Each record represents an interaction or session event.


CREATE TABLE rel_src.events (
  event_id     bigserial PRIMARY KEY,
  customer_id  bigint REFERENCES rel_src.customers(customer_id),
  session_id   uuid NOT NULL DEFAULT gen_random_uuid(),
  event_ts     timestamptz NOT NULL DEFAULT now(),
  event_type   text NOT NULL,
  payload      jsonb NOT NULL  -- flexible: page, device, geo, search term, etc.
);

-- Example JSON payload:
-- {
--   "page": "/home",
--   "device": "mobile",
--   "ref": "email",
--   "geo": { "lat": 53.35, "lon": -6.26 }
-- }

-- -----------------------------------------------
-- Helpful indexes
-- -----------------------------------------------
CREATE INDEX ON rel_src.customers(region_id);
CREATE INDEX ON rel_src.orders(order_date);
CREATE INDEX ON rel_src.orders(customer_id);
CREATE INDEX ON rel_src.orders(merchant_id);
CREATE INDEX ON rel_src.order_items(product_id);
CREATE INDEX products_gin_attr ON rel_src.products USING gin(attributes);
CREATE INDEX events_ts_idx ON rel_src.events(event_ts);
CREATE INDEX events_customer_idx ON rel_src.events(customer_id);
CREATE INDEX events_payload_gin ON rel_src.events USING gin(payload);

-- -----------------------------------------------
-- End of schema
-- -----------------------------------------------
