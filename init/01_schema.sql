-- Учебная БД: розничные продажи (ClickHouse)
DROP DATABASE IF EXISTS retail_dw SYNC;
CREATE DATABASE retail_dw;

CREATE TABLE retail_dw.dim_goods
(
    sku_id UInt32,
    item_name String,
    dept LowCardinality(String),
    maker String,
    measure_unit LowCardinality(String),
    list_price Decimal(10, 2),
    vendor_id UInt16
)
ENGINE = MergeTree
ORDER BY sku_id;

CREATE TABLE retail_dw.dim_client
(
    client_id UInt32,
    client_name String,
    sex LowCardinality(String),
    birth_year UInt16,
    home_city LowCardinality(String),
    is_loyal UInt8,
    signup_date Date
)
ENGINE = MergeTree
ORDER BY client_id;

CREATE TABLE retail_dw.fact_receipt
(
    receipt_line_id UInt64,
    sold_at DateTime,
    client_id UInt32,
    sku_id UInt32,
    qty Decimal(10, 1),
    sell_price Decimal(10, 2),
    line_total Decimal(12, 2),
    pay_method LowCardinality(String),
    shop_id UInt8
)
ENGINE = MergeTree
ORDER BY (sold_at, shop_id, sku_id);
