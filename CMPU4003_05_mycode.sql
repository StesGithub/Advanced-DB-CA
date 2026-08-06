CREATE EXTENSION IF NOT EXISTS pg_prewarm;

SELECT pg_prewarm('dw_lite.fact_c21394693_regional_performance_by_merchant');