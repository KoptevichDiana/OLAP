DROP TABLE IF EXISTS fact_writeoff;
DROP TABLE IF EXISTS fact_supply;
DROP TABLE IF EXISTS fact_receipt_line;
DROP TABLE IF EXISTS dim_goods;
DROP TABLE IF EXISTS dim_supplier;
DROP TABLE IF EXISTS dim_client;
DROP TABLE IF EXISTS dim_shop;
DROP TABLE IF EXISTS dim_calendar;
DROP TABLE IF EXISTS dim_pay_method;
DROP TABLE IF EXISTS dim_transport;
DROP TABLE IF EXISTS dim_writeoff_reason;

CREATE TABLE dim_supplier (
    supplier_id    INTEGER PRIMARY KEY,
    supplier_name  VARCHAR NOT NULL,
    supplier_type  VARCHAR,
    city           VARCHAR,
    contract_year  SMALLINT
);

CREATE TABLE dim_goods (
    sku_id              INTEGER PRIMARY KEY,
    item_name           VARCHAR NOT NULL,
    dept                VARCHAR NOT NULL,
    maker               VARCHAR,
    measure_unit        VARCHAR NOT NULL,
    list_price          DECIMAL(10,2) NOT NULL,
    vendor_id           INTEGER,
    description         VARCHAR,
    kcal                SMALLINT,
    protein_g           DECIMAL(5,1),
    fat_g               DECIMAL(5,1),
    carbs_g             DECIMAL(5,1),
    shelf_life_days     SMALLINT NOT NULL,
    storage_conditions  VARCHAR,
    FOREIGN KEY (vendor_id) REFERENCES dim_supplier(supplier_id)
);

CREATE TABLE dim_client (
    client_id    INTEGER PRIMARY KEY,
    client_name  VARCHAR NOT NULL,
    sex          VARCHAR,
    birth_year   SMALLINT,
    home_city    VARCHAR,
    is_loyal     BOOLEAN NOT NULL,
    signup_date  DATE
);

CREATE TABLE dim_shop (
    shop_id    INTEGER PRIMARY KEY,
    shop_name  VARCHAR NOT NULL,
    city       VARCHAR NOT NULL,
    address    VARCHAR,
    format     VARCHAR,
    area_m2    INTEGER,
    open_date  DATE
);

CREATE TABLE dim_calendar (
    date_key      DATE PRIMARY KEY,
    year          SMALLINT NOT NULL,
    quarter       TINYINT  NOT NULL,
    month         TINYINT  NOT NULL,
    month_name    VARCHAR  NOT NULL,
    day           TINYINT  NOT NULL,
    weekday       TINYINT  NOT NULL,
    weekday_name  VARCHAR  NOT NULL,
    is_weekend    BOOLEAN  NOT NULL,
    is_holiday    BOOLEAN  NOT NULL
);

CREATE TABLE dim_pay_method (
    pay_method_id  INTEGER PRIMARY KEY,
    pay_method     VARCHAR NOT NULL UNIQUE
);

CREATE TABLE dim_transport (
    transport_id     INTEGER PRIMARY KEY,
    transport_name   VARCHAR NOT NULL,
    body_type        VARCHAR,
    capacity_t       DECIMAL(4,1),
    is_refrigerated  BOOLEAN NOT NULL,
    temp_range       VARCHAR
);

CREATE TABLE dim_writeoff_reason (
    reason_id          INTEGER PRIMARY KEY,
    reason_name        VARCHAR NOT NULL,
    reason_group       VARCHAR,
    is_supplier_fault  BOOLEAN NOT NULL
);

CREATE TABLE fact_receipt_line (
    receipt_line_id  BIGINT PRIMARY KEY,
    sold_at          TIMESTAMP NOT NULL,
    client_id        INTEGER   NOT NULL,
    sku_id           INTEGER   NOT NULL,
    shop_id          INTEGER   NOT NULL,
    pay_method_id    INTEGER   NOT NULL,
    qty              DECIMAL(10,1) NOT NULL,
    sell_price       DECIMAL(10,2) NOT NULL,
    line_total       DECIMAL(12,2) NOT NULL,
    FOREIGN KEY (client_id)     REFERENCES dim_client(client_id),
    FOREIGN KEY (sku_id)        REFERENCES dim_goods(sku_id),
    FOREIGN KEY (shop_id)       REFERENCES dim_shop(shop_id),
    FOREIGN KEY (pay_method_id) REFERENCES dim_pay_method(pay_method_id)
);

CREATE TABLE fact_supply (
    supply_id       BIGINT PRIMARY KEY,
    shipped_at      TIMESTAMP NOT NULL,
    delivered_at    TIMESTAMP NOT NULL,
    supplier_id     INTEGER   NOT NULL,
    shop_id         INTEGER   NOT NULL,
    sku_id          INTEGER   NOT NULL,
    transport_id    INTEGER   NOT NULL,
    qty             DECIMAL(10,1) NOT NULL,
    purchase_price  DECIMAL(10,2) NOT NULL,
    supply_amount   DECIMAL(12,2) NOT NULL,
    expiry_date     DATE NOT NULL,
    FOREIGN KEY (supplier_id)  REFERENCES dim_supplier(supplier_id),
    FOREIGN KEY (shop_id)      REFERENCES dim_shop(shop_id),
    FOREIGN KEY (sku_id)       REFERENCES dim_goods(sku_id),
    FOREIGN KEY (transport_id) REFERENCES dim_transport(transport_id)
);

CREATE TABLE fact_writeoff (
    writeoff_id     BIGINT PRIMARY KEY,
    written_off_at  TIMESTAMP NOT NULL,
    shop_id         INTEGER   NOT NULL,
    sku_id          INTEGER   NOT NULL,
    supply_id       BIGINT    NOT NULL,
    reason_id       INTEGER   NOT NULL,
    qty             DECIMAL(10,1) NOT NULL,
    cost_amount     DECIMAL(12,2) NOT NULL,
    FOREIGN KEY (shop_id)   REFERENCES dim_shop(shop_id),
    FOREIGN KEY (sku_id)    REFERENCES dim_goods(sku_id),
    FOREIGN KEY (supply_id) REFERENCES fact_supply(supply_id),
    FOREIGN KEY (reason_id) REFERENCES dim_writeoff_reason(reason_id)
);
