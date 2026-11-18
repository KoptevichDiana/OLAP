-- P07: схема ClickHouse для витрины P03/P05 продуктового ритейла

-- ORDER BY задаёт сортировку/индекс, НЕ обеспечивает уникальность.

CREATE DATABASE IF NOT EXISTS olap;

CREATE TABLE IF NOT EXISTS olap.dim_supplier (
    supplier_id Int32,
    supplier_name String,
    supplier_type Nullable(String),
    city Nullable(String),
    contract_year Nullable(Int16)
) ENGINE = MergeTree
ORDER BY (supplier_id);

CREATE TABLE IF NOT EXISTS olap.dim_goods (
    sku_id Int32,
    item_name String,
    dept String,
    maker Nullable(String),
    measure_unit String,
    list_price Decimal(10,2),
    vendor_id Nullable(Int32),
    description Nullable(String),
    kcal Nullable(Int16),
    protein_g Nullable(Decimal(5,1)),
    fat_g Nullable(Decimal(5,1)),
    carbs_g Nullable(Decimal(5,1)),
    shelf_life_days Int16,
    storage_conditions Nullable(String)
) ENGINE = MergeTree
ORDER BY (sku_id);

CREATE TABLE IF NOT EXISTS olap.dim_client (
    client_id Int32,
    client_name String,
    sex Nullable(String),
    birth_year Nullable(Int16),
    home_city Nullable(String),
    is_loyal Bool,
    signup_date Nullable(Date)
) ENGINE = MergeTree
ORDER BY (client_id);

CREATE TABLE IF NOT EXISTS olap.dim_shop (
    shop_id Int32,
    shop_name String,
    city String,
    address Nullable(String),
    format Nullable(String),
    area_m2 Nullable(Int32),
    open_date Nullable(Date)
) ENGINE = MergeTree
ORDER BY (shop_id);

CREATE TABLE IF NOT EXISTS olap.dim_calendar (
    date_key Date,
    year Int16,
    quarter Int8,
    month Int8,
    month_name String,
    day Int8,
    weekday Int8,
    weekday_name String,
    is_weekend Bool,
    is_holiday Bool
) ENGINE = MergeTree
ORDER BY (date_key);

CREATE TABLE IF NOT EXISTS olap.dim_pay_method (
    pay_method_id Int32,
    pay_method String
) ENGINE = MergeTree
ORDER BY (pay_method_id);

CREATE TABLE IF NOT EXISTS olap.dim_transport (
    transport_id Int32,
    transport_name String,
    body_type Nullable(String),
    capacity_t Nullable(Decimal(4,1)),
    is_refrigerated Bool,
    temp_range Nullable(String)
) ENGINE = MergeTree
ORDER BY (transport_id);

CREATE TABLE IF NOT EXISTS olap.dim_writeoff_reason (
    reason_id Int32,
    reason_name String,
    reason_group Nullable(String),
    is_supplier_fault Bool
) ENGINE = MergeTree
ORDER BY (reason_id);

CREATE TABLE IF NOT EXISTS olap.fact_receipt_line (
    receipt_line_id Int64,
    sold_at DateTime,
    client_id Int32,
    sku_id Int32,
    shop_id Int32,
    pay_method_id Int32,
    qty Decimal(10,1),
    sell_price Decimal(10,2),
    line_total Decimal(12,2)
) ENGINE = MergeTree
ORDER BY (sold_at, shop_id, receipt_line_id);

CREATE TABLE IF NOT EXISTS olap.fact_supply (
    supply_id Int64,
    shipped_at DateTime,
    delivered_at DateTime,
    supplier_id Int32,
    shop_id Int32,
    sku_id Int32,
    transport_id Int32,
    qty Decimal(10,1),
    purchase_price Decimal(10,2),
    supply_amount Decimal(12,2),
    expiry_date Date
) ENGINE = MergeTree
ORDER BY (shipped_at, shop_id, supply_id);

CREATE TABLE IF NOT EXISTS olap.fact_writeoff (
    writeoff_id Int64,
    written_off_at DateTime,
    shop_id Int32,
    sku_id Int32,
    supply_id Int64,
    reason_id Int32,
    qty Decimal(10,1),
    cost_amount Decimal(12,2)
) ENGINE = MergeTree
ORDER BY (written_off_at, shop_id, writeoff_id);
