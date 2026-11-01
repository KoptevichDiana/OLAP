-- З03. DDL для DuckDB. Сеть продуктовых магазинов (12 точек), 2024 год.
-- Схема «звезда» по паспорту P02: 5 измерений + 1 факт.
-- Факт fact_receipt_line: одна строка = одна строка чека.
-- Деньги — DECIMAL, не FLOAT.
-- Таблицы удаляются и создаются заново → повторный запуск не удваивает данные.

DROP TABLE IF EXISTS fact_receipt_line;   -- сначала факт (он ссылается на справочники)
DROP TABLE IF EXISTS dim_goods;
DROP TABLE IF EXISTS dim_client;
DROP TABLE IF EXISTS dim_shop;
DROP TABLE IF EXISTS dim_pay_method;
DROP TABLE IF EXISTS dim_calendar;

-- ------------------------------------------------------------
-- ИЗМЕРЕНИЯ
-- ------------------------------------------------------------

-- Один товар. Источник: data/raw/dim_goods.csv
CREATE TABLE dim_goods (
    sku_id         INTEGER PRIMARY KEY,
    item_name      VARCHAR NOT NULL,
    dept           VARCHAR NOT NULL,          -- отдел
    maker          VARCHAR,                   -- производитель
    measure_unit   VARCHAR NOT NULL,          -- 'шт' / 'кг'
    list_price     DECIMAL(10,2) NOT NULL,    -- цена по прайсу
    vendor_id      INTEGER                    -- поставщик (только номер)
);

-- Один клиент. Источник: data/raw/dim_client.csv
CREATE TABLE dim_client (
    client_id      INTEGER PRIMARY KEY,
    client_name    VARCHAR NOT NULL,
    sex            VARCHAR,                   -- 'М' / 'Ж'
    birth_year     SMALLINT,
    home_city      VARCHAR,
    is_loyal       BOOLEAN NOT NULL,          -- в CSV 1 / 0
    signup_date    DATE
);

-- Один магазин. Файла нет — номера 1–12 берём из факта.
CREATE TABLE dim_shop (
    shop_id        INTEGER PRIMARY KEY,
    shop_name      VARCHAR NOT NULL
);

-- Один способ оплаты. Файла нет — 4 значения берём из факта.
CREATE TABLE dim_pay_method (
    pay_method_id  INTEGER PRIMARY KEY,
    pay_method     VARCHAR NOT NULL UNIQUE
);

-- Один календарный день 2024 года. Генерируется.
CREATE TABLE dim_calendar (
    date_key       DATE PRIMARY KEY,
    year           SMALLINT NOT NULL,
    quarter        TINYINT  NOT NULL,
    month          TINYINT  NOT NULL,
    month_name     VARCHAR  NOT NULL,
    weekday        TINYINT  NOT NULL,         -- 1 = пн … 7 = вс
    is_weekend     BOOLEAN  NOT NULL
);

-- ------------------------------------------------------------
-- ФАКТ
-- ------------------------------------------------------------

-- Одна строка = одна строка чека. Источник: data/raw/fact_receipt.csv
CREATE TABLE fact_receipt_line (
    receipt_line_id BIGINT PRIMARY KEY,
    sold_at         TIMESTAMP NOT NULL,       -- дата → dim_calendar.date_key
    client_id       INTEGER   NOT NULL,
    sku_id          INTEGER   NOT NULL,
    shop_id         INTEGER   NOT NULL,
    pay_method_id   INTEGER   NOT NULL,
    qty             DECIMAL(10,1) NOT NULL,   -- шт или кг (см. dim_goods.measure_unit)
    sell_price      DECIMAL(10,2) NOT NULL,   -- цена за единицу, не суммируется
    line_total      DECIMAL(12,2) NOT NULL,   -- главная мера: выручка строки
    FOREIGN KEY (client_id)     REFERENCES dim_client(client_id),
    FOREIGN KEY (sku_id)        REFERENCES dim_goods(sku_id),
    FOREIGN KEY (shop_id)       REFERENCES dim_shop(shop_id),
    FOREIGN KEY (pay_method_id) REFERENCES dim_pay_method(pay_method_id)
);
