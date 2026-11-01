-- З05. Заполнение витрины из промежуточных таблиц stg_* (их создаёт etl/load_data.py).
-- Порядок: сначала справочники, потом факт.

-- Товары
INSERT INTO dim_goods
SELECT sku_id::INTEGER, item_name, dept, maker, measure_unit,
       list_price::DECIMAL(10,2), vendor_id::INTEGER
FROM stg_goods;

-- Клиенты
INSERT INTO dim_client
SELECT client_id::INTEGER, client_name, sex, birth_year::SMALLINT,
       home_city, is_loyal = '1', signup_date::DATE
FROM stg_client;

-- Магазины 1–12
INSERT INTO dim_shop
SELECT i::INTEGER, 'Магазин №' || i
FROM range(1, 13) AS t(i);

-- Способы оплаты: уникальные значения из факта
INSERT INTO dim_pay_method
SELECT ROW_NUMBER() OVER (ORDER BY pay_method)::INTEGER, pay_method
FROM (SELECT DISTINCT pay_method FROM stg_receipt);

-- Календарь 2024 года
INSERT INTO dim_calendar
SELECT d::DATE, year(d), quarter(d), month(d),
       ['Январь','Февраль','Март','Апрель','Май','Июнь',
        'Июль','Август','Сентябрь','Октябрь','Ноябрь','Декабрь'][month(d)],
       isodow(d), isodow(d) IN (6, 7)
FROM generate_series(TIMESTAMP '2024-01-01', TIMESTAMP '2024-12-31', INTERVAL 1 DAY) AS t(d);

-- Факт (последним)
INSERT INTO fact_receipt_line
SELECT r.receipt_line_id::BIGINT, r.sold_at::TIMESTAMP,
       r.client_id::INTEGER, r.sku_id::INTEGER, r.shop_id::INTEGER,
       p.pay_method_id,
       r.qty::DECIMAL(10,1), r.sell_price::DECIMAL(10,2), r.line_total::DECIMAL(12,2)
FROM stg_receipt AS r
JOIN dim_pay_method p ON p.pay_method = r.pay_method;
