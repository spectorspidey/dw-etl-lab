CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS dw;
-- Staging: one cleaned batch at a time, truncated on every load
CREATE TABLE IF NOT EXISTS staging.stg_sales (
    order_id TEXT,
    order_date DATE,
    store_id TEXT,
    store_name TEXT,
    barangay TEXT,
    city TEXT,
    product_id TEXT,
    product_name TEXT,
    category TEXT,
    quantity INTEGER,
    unit_price NUMERIC(10,2),
    line_total NUMERIC(12,2),
    batch_id TEXT
);
-- Dimensions
CREATE TABLE IF NOT EXISTS dw.dim_date (
    date_key INTEGER PRIMARY KEY, -- YYYYMMDD
    full_date DATE NOT NULL UNIQUE,
    day_of_week TEXT,
    is_weekend BOOLEAN,
    month INTEGER,
    month_name TEXT,
    quarter INTEGER,
    year INTEGER
);
CREATE TABLE IF NOT EXISTS dw.dim_store (
    store_key SERIAL PRIMARY KEY, -- surrogate key
    store_id TEXT NOT NULL UNIQUE, -- natural key from the source
    store_name TEXT,
    barangay TEXT,
    city TEXT
);
CREATE TABLE IF NOT EXISTS dw.dim_product (
    product_key SERIAL PRIMARY KEY,
    product_id TEXT NOT NULL UNIQUE,
    product_name TEXT,
    category TEXT
);
-- Fact: grain = one product line on one order
CREATE TABLE IF NOT EXISTS dw.fact_sales (
    sales_key BIGSERIAL PRIMARY KEY,
    order_id TEXT NOT NULL,
    date_key INTEGER NOT NULL REFERENCES dw.dim_date(date_key),
    store_key INTEGER NOT NULL REFERENCES dw.dim_store(store_key),
    product_key INTEGER NOT NULL REFERENCES dw.dim_product(product_key),
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL,
    line_total NUMERIC(12,2) NOT NULL,
    batch_id TEXT,
    UNIQUE (order_id, product_key) -- makes reloads idempotent
);
-- Data Mart View: dw.v_daily_category_sales (Extension C)
CREATE MATERIALIZED VIEW IF NOT EXISTS dw.v_daily_category_sales AS
SELECT
    dd.full_date,
    dp.category,
    COUNT(DISTINCT fs.order_id) AS total_orders,
    SUM(fs.quantity) AS total_units_sold,
    SUM(fs.line_total) AS total_sales_php
FROM dw.fact_sales fs
JOIN dw.dim_date dd ON fs.date_key = dd.date_key
JOIN dw.dim_product dp ON fs.product_key = dp.product_key
GROUP BY dd.full_date, dp.category;

CREATE UNIQUE INDEX IF NOT EXISTS idx_v_daily_category_sales
ON dw.v_daily_category_sales (full_date, category);
