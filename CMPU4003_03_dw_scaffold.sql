-- ===============================================
-- CMPU4003_03_dw_scaffold.sql : Data Warehouse Scaffold 
-- ===============================================

DROP SCHEMA IF EXISTS dw_lite CASCADE;
CREATE SCHEMA dw_lite;
SET search_path = dw_lite, public;

-- Added extension pg_prewarm
CREATE EXTENSION IF NOT EXISTS pg_prewarm;

-- -------------------------
-- DIMENSIONS
-- -------------------------

CREATE TABLE dw_lite.dim_date (
    date_key INT PRIMARY KEY,
    date_actual DATE,
    year INT,
    month INT,
    day INT
);

CREATE TABLE dw_lite.dim_customer (
    customer_key BIGINT PRIMARY KEY,
    region TEXT,
    full_name TEXT,
    age_band TEXT
);

CREATE TABLE dw_lite.dim_product (
    product_key BIGINT PRIMARY KEY,
    category TEXT,
    merchant TEXT,
    price NUMERIC(12,2)
);

-- NEW DIMENSIONAL MODELLING ADDED BY ME
CREATE TABLE dw_lite.dim_merchant (
    merchant_key BIGINT PRIMARY KEY,
    merchant_name TEXT,
    region TEXT
);

CREATE TABLE dw_lite.dim_region (
    region_key SMALLINT PRIMARY KEY,
    region_code TEXT,
    region_name TEXT
);

-- -------------------------
-- LOAD DIMENSIONS
-- -------------------------
INSERT INTO dw_lite.dim_date(date_key, date_actual, year, month, day)
SELECT to_char(d,'YYYYMMDD')::int, d,
       EXTRACT(YEAR FROM d)::int,
       EXTRACT(MONTH FROM d)::int,
       EXTRACT(DAY FROM d)::int
FROM generate_series(current_date - interval '90 days', current_date, interval '1 day') d;

INSERT INTO dw_lite.dim_customer(customer_key, region, full_name, age_band)
SELECT c.customer_id,
       r.region_name,
       c.full_name,
       c.attributes ->> 'age_band'
FROM rel_src.customers c
JOIN rel_src.regions r ON r.region_id = c.region_id;

INSERT INTO dw_lite.dim_product(product_key, category, merchant, price)
SELECT p.product_id,
       cat.category_name,
       m.merchant_name,
       p.base_price
FROM rel_src.products p
JOIN rel_src.categories cat ON cat.category_id = p.category_id
JOIN rel_src.merchants m ON m.merchant_id = p.merchant_id;

-- NEW DIMENSION LOADS ADDED BY ME
INSERT INTO dw_lite.dim_merchant(merchant_key, merchant_name, region)
SELECT m.merchant_id,
       m.merchant_name,
       r.region_name
FROM rel_src.merchants m
JOIN rel_src.regions r ON r.region_id = m.region_id;

INSERT INTO dw_lite.dim_region(region_key, region_code, region_name)
SELECT r.region_id,
       r.region_code,
       r.region_name
FROM rel_src.regions r;


-- -------------------------
-- FACT (yours to define)
-- -------------------------
-- Think: What should one row in your fact table represent?
-- Is it an order, an order item, or a daily summary?
-- What are the measures (facts) you would include?


-- FACT TABLE 
CREATE TABLE dw_lite.fact_c21394693_fact_region_revenue (
    region_key INT REFERENCES dw_lite.dim_region(region_key),
    total_sales NUMERIC(14,2), 
    total_orders INT,
    unique_customers INT,
    avg_spend NUMERIC(12,2),
    unique_merchants INT,
    performance_meta JSONB DEFAULT '{}'::jsonb
);

INSERT INTO dw_lite.fact_c21394693_fact_region_revenue (
    region_key,
    total_sales,
    total_orders,
    unique_customers,
    avg_spend,
    unique_merchants,
    performance_meta
)
SELECT
    dr.region_key,
    SUM (o.total_amount) AS total_sales,
    COUNT(o.order_id) AS total_orders,
    COUNT(DISTINCT o.customer_id) AS unique_customers,
    SUM (o.total_amount)/ COUNT(o.order_id) AS avg_spend,
    COUNT(DISTINCT m.merchant_id) AS unique_merchants,
    '{"analysis" : "regional performance by merchant"}'::jsonb AS performance_meta
FROM 
    rel_src.orders o
    JOIN rel_src.customers c ON o.customer_id = c.customer_id
    JOIN rel_src.regions r ON c.region_id = r.region_id
    JOIN rel_src.merchants m ON o.merchant_id = m.merchant_id
    JOIN dw_lite.dim_region dr ON r.region_id = dr.region_key
GROUP BY
    dr.region_key;


-- Highest revenue by region
SELECT 
    dr.region_name AS Region,
    f.total_sales AS TotalSales,
    f.total_orders AS TotalOrders
    
FROM
    dw_lite.fact_c21394693_fact_region_revenue f
JOIN
    dw_lite.dim_region dr ON f.region_key = dr.region_key
ORDER BY
    TotalSales DESC;


-- Average revenue by customer per region
SELECT 
    dr.region_name AS Region,
    f.unique_customers AS UniqueCustomers,
    f.avg_spend AS AverageSpend
FROM 
    dw_lite.fact_c21394693_fact_region_revenue f
JOIN
    dw_lite.dim_region dr ON f.region_key = dr.region_key
ORDER BY
    AverageSpend DESC;
    

EXPLAIN ANALYZE SELECT * FROM dw_lite.fact_c21394693_fact_region_revenue;

--UNLOGGED ADDED BY ME
ALTER TABLE dw_lite.fact_c21394693_fact_region_revenue SET UNLOGGED;

EXPLAIN ANALYZE SELECT * FROM dw_lite.fact_c21394693_fact_region_revenue;

--TEMP TABLE
CREATE TEMP TABLE temp_fact_region_revenue AS SELECT * FROM dw_lite.fact_c21394693_fact_region_revenue;

EXPLAIN ANALYZE SELECT * FROM temp_fact_region_revenue;

--pg_prewarm
SELECT pg_prewarm('dw_lite.fact_c21394693_fact_region_revenue');

EXPLAIN ANALYZE SELECT * FROM dw_lite.fact_c21394693_fact_region_revenue;


-- -------------------------
-- NEXT STEPS 
-- -------------------------
-- 1. Decide the grain of dw_lite.fact_sales (row per order, per item, per day?).
-- 2. Identify which dimensions it links to (dim_date, dim_customer, dim_product?).
-- 3. Decide which numeric measures (facts) to store.
-- 4. Write an INSERT INTO dw_lite.fact_sales (...) SELECT ... FROM rel_src.orders ...
-- 5. Test your design with queries and EXPLAIN ANALYZE.

-- Example to adapt:
-- INSERT INTO dw_lite.fact_sales(date_key, customer_key, product_key, total_amount)
-- SELECT to_char(o.order_date,'YYYYMMDD')::int,
--        o.customer_id,
--        oi.product_id,
--        SUM(oi.quantity * oi.unit_price)
-- FROM rel_src.orders o
-- JOIN rel_src.order_items oi ON oi.order_id = o.order_id
-- GROUP BY 1,2,3;

ANALYZE;
