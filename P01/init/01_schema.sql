DROP DATABASE IF EXISTS retail_dw SYNC;
CREATE DATABASE retail_dw;

CREATE TABLE retail_dw.dim_goods
(
    sku_id             UInt32,
    item_name          String,
    dept               LowCardinality(String),
    maker              String,
    measure_unit       LowCardinality(String),
    list_price         Decimal(10, 2),
    vendor_id          UInt16,
    description        String,
    kcal               Nullable(UInt16),
    protein_g          Nullable(Decimal(5, 1)),
    fat_g              Nullable(Decimal(5, 1)),
    carbs_g            Nullable(Decimal(5, 1)),
    shelf_life_days    UInt16,
    storage_conditions String
)
ENGINE = MergeTree
ORDER BY sku_id;

CREATE TABLE retail_dw.dim_client
(
    client_id   UInt32,
    client_name String,
    sex         LowCardinality(String),
    birth_year  UInt16,
    home_city   LowCardinality(String),
    is_loyal    UInt8,
    signup_date Date
)
ENGINE = MergeTree
ORDER BY client_id;

CREATE TABLE retail_dw.dim_shop
(
    shop_id   UInt8,
    shop_name String,
    city      LowCardinality(String),
    address   String,
    format    LowCardinality(String),
    area_m2   UInt16,
    open_date Date
)
ENGINE = MergeTree
ORDER BY shop_id;

CREATE TABLE retail_dw.dim_date
(
    date_key     Date,
    year         UInt16,
    quarter      UInt8,
    month        UInt8,
    month_name   LowCardinality(String),
    day          UInt8,
    weekday      UInt8,
    weekday_name LowCardinality(String),
    is_weekend   UInt8,
    is_holiday   UInt8
)
ENGINE = MergeTree
ORDER BY date_key;

CREATE TABLE retail_dw.dim_supplier
(
    supplier_id   UInt16,
    supplier_name String,
    supplier_type LowCardinality(String),
    city          LowCardinality(String),
    contract_year UInt16
)
ENGINE = MergeTree
ORDER BY supplier_id;

CREATE TABLE retail_dw.dim_transport
(
    transport_id    UInt8,
    transport_name  String,
    body_type       LowCardinality(String),
    capacity_t      Decimal(4, 1),
    is_refrigerated UInt8,
    temp_range      String
)
ENGINE = MergeTree
ORDER BY transport_id;

CREATE TABLE retail_dw.dim_writeoff_reason
(
    reason_id         UInt8,
    reason_name       String,
    reason_group      LowCardinality(String),
    is_supplier_fault UInt8
)
ENGINE = MergeTree
ORDER BY reason_id;

CREATE TABLE retail_dw.fact_receipt
(
    receipt_line_id UInt64,
    sold_at         DateTime,
    client_id       UInt32,
    sku_id          UInt32,
    qty             Decimal(10, 1),
    sell_price      Decimal(10, 2),
    line_total      Decimal(12, 2),
    pay_method      LowCardinality(String),
    shop_id         UInt8
)
ENGINE = MergeTree
ORDER BY (sold_at, shop_id, sku_id);

CREATE TABLE retail_dw.fact_supply
(
    supply_id      UInt64,
    shipped_at     DateTime,
    delivered_at   DateTime,
    supplier_id    UInt16,
    shop_id        UInt8,
    sku_id         UInt32,
    transport_id   UInt8,
    qty            Decimal(10, 1),
    purchase_price Decimal(10, 2),
    supply_amount  Decimal(12, 2),
    expiry_date    Date
)
ENGINE = MergeTree
ORDER BY (delivered_at, shop_id, sku_id);

CREATE TABLE retail_dw.fact_writeoff
(
    writeoff_id    UInt64,
    written_off_at DateTime,
    shop_id        UInt8,
    sku_id         UInt32,
    supply_id      UInt64,
    reason_id      UInt8,
    qty            Decimal(10, 1),
    cost_amount    Decimal(12, 2)
)
ENGINE = MergeTree
ORDER BY (written_off_at, shop_id, sku_id);
