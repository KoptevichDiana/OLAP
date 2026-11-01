-- З05. DDL витрины для DuckDB (та же «звезда», что в P03).
-- Отличие от P03: таблицы НЕ удаляются (CREATE TABLE IF NOT EXISTS).
-- Повтор загрузки решается в etl/load_data.py: таблицы очищаются и заполняются заново.

-- ------------------------------------------------------------
-- ИЗМЕРЕНИЯ
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS dim_goods (
    sku_id         INTEGER PRIMARY KEY,
    item_name      VARCHAR NOT NULL,
    dept           VARCHAR NOT NULL,          -- отдел
    maker          VARCHAR,                   -- производитель
    measure_unit   VARCHAR NOT NULL,          -- 'шт' / 'кг'
    list_price     DECIMAL(10,2) NOT NULL,    -- цена по прайсу
    vendor_id      INTEGER                    -- поставщик (только номер)
);

CREATE TABLE IF NOT EXISTS dim_client (
    client_id      INTEGER PRIMARY KEY,
    client_name    VARCHAR NOT NULL,
    sex            VARCHAR,
    birth_year     SMALLINT,
    home_city      VARCHAR,
    is_loyal       BOOLEAN NOT NULL,
    signup_date    DATE
);

-- Магазины 1–12. Файла нет — справочник создаётся в загрузке.
CREATE TABLE IF NOT EXISTS dim_shop (
    shop_id        INTEGER PRIMARY KEY,
    shop_name      VARCHAR NOT NULL
);

CREATE TABLE IF NOT EXISTS dim_pay_method (
    pay_method_id  INTEGER PRIMARY KEY,
    pay_method     VARCHAR NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS dim_calendar (
    date_key       DATE PRIMARY KEY,
    year           SMALLINT NOT NULL,
    quarter        TINYINT  NOT NULL,
    month          TINYINT  NOT NULL,
    month_name     VARCHAR  NOT NULL,
    weekday        TINYINT  NOT NULL,         -- 1 = пн … 7 = вс
    is_weekend     BOOLEAN  NOT NULL
);

-- ------------------------------------------------------------
-- ФАКТ: одна строка = одна строка чека
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS fact_receipt_line (
    receipt_line_id BIGINT PRIMARY KEY,
    sold_at         TIMESTAMP NOT NULL,
    client_id       INTEGER   NOT NULL,
    sku_id          INTEGER   NOT NULL,
    shop_id         INTEGER   NOT NULL,
    pay_method_id   INTEGER   NOT NULL,
    qty             DECIMAL(10,1) NOT NULL,
    sell_price      DECIMAL(10,2) NOT NULL,
    line_total      DECIMAL(12,2) NOT NULL,
    FOREIGN KEY (client_id)     REFERENCES dim_client(client_id),
    FOREIGN KEY (sku_id)        REFERENCES dim_goods(sku_id),
    FOREIGN KEY (shop_id)       REFERENCES dim_shop(shop_id),
    FOREIGN KEY (pay_method_id) REFERENCES dim_pay_method(pay_method_id)
);
