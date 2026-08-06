
-- ===============================================
-- CMPU4003_02_generate_relational_data.sql : Synthetic Data Generator (Lite)
-- ===============================================


SET search_path = rel_src, public;

-- Regions and categories
INSERT INTO rel_src.regions(region_code, region_name) VALUES
 ('IE','Ireland'),('UK','United Kingdom'),('EU','Europe'),('US','United States');

INSERT INTO rel_src.categories(category_name) 
SELECT 'Category '||g FROM generate_series(1,10) g;

-- Merchants
INSERT INTO rel_src.merchants(merchant_name, region_id)
SELECT 'Merchant '||g, (random()*3+1)::int FROM generate_series(1,20) g;

-- Products
INSERT INTO rel_src.products(category_id, merchant_id, sku, product_name, base_price, attributes)
SELECT
 (random()*9+1)::int,
 (random()*19+1)::int,
 'SKU-'||g,
 'Product '||g,
 round((random()*100+5)::numeric,2),
 jsonb_build_object('color',(ARRAY['red','blue','green'])[1+(random()*2)::int])
FROM generate_series(1,500) g;

-- Customers
INSERT INTO rel_src.customers(region_id, full_name, email, created_at, attributes)
SELECT
 (random()*3+1)::int,
 'Customer '||g,
 'cust'||g||'@mail.com',
 now() - (random()*'180 days'::interval),
 jsonb_build_object('age_band',(ARRAY['18-24','25-34','35-44','45+'])[1+(random()*3)::int])
FROM generate_series(1,5000) g;

-- Orders and items
INSERT INTO rel_src.orders(customer_id, merchant_id, order_ts, status, total_amount, meta)
SELECT
 (random()*4999+1)::int,
 (random()*19+1)::int,
 now() - (random()*'60 days'::interval),
 (ARRAY['paid','shipped','delivered'])[1+(random()*2)::int],
 round((random()*200+10)::numeric,2),
 jsonb_build_object('coupon',(ARRAY['SAVE10','WELCOME','NONE'])[1+(random()*2)::int])
FROM generate_series(1,20000) g;

INSERT INTO rel_src.order_items(order_id, item_no, product_id, quantity, unit_price, discount)
SELECT
 o.order_id,
 gs AS item_no,
 (random()*499+1)::int,
 (random()*3+1)::int,
 round((random()*100+5)::numeric,2),
 0
FROM orders o, generate_series(1,2) gs;

ANALYZE;


