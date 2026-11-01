-- З03. Загрузка CSV из data/raw/ в таблицы.
-- Запускается после ddl_duckdb.sql, из папки P03/.
-- Порядок: сначала справочники, потом факт (из-за FOREIGN KEY).

-- Товары
INSERT INTO dim_goods
SELECT sku_id::INTEGER, item_name, dept, maker, measure_unit,
       list_price::DECIMAL(10,2), vendor_id::INTEGER
FROM read_csv('data/raw/dim_goods.csv', header = true, all_varchar = true);

-- Клиенты
INSERT INTO dim_client
SELECT client_id::INTEGER, client_name, sex, birth_year::SMALLINT,
       home_city, is_loyal = '1', signup_date::DATE
FROM read_csv('data/raw/dim_client.csv', header = true, all_varchar = true);

-- Магазины: уникальные номера из факта
INSERT INTO dim_shop
SELECT shop_id, 'Магазин №' || shop_id
FROM (SELECT DISTINCT shop_id::INTEGER AS shop_id
      FROM read_csv('data/raw/fact_receipt.csv', header = true, all_varchar = true))
ORDER BY shop_id;

-- Способы оплаты: уникальные значения из факта, нумерация по алфавиту
INSERT INTO dim_pay_method
SELECT ROW_NUMBER() OVER (ORDER BY pay_method)::INTEGER, pay_method
FROM (SELECT DISTINCT pay_method
      FROM read_csv('data/raw/fact_receipt.csv', header = true, all_varchar = true));

-- Календарь на весь 2024 год (366 дней, год високосный)
INSERT INTO dim_calendar
SELECT d::DATE, year(d), quarter(d), month(d),
       ['Январь','Февраль','Март','Апрель','Май','Июнь',
        'Июль','Август','Сентябрь','Октябрь','Ноябрь','Декабрь'][month(d)],
       isodow(d), isodow(d) IN (6, 7)
FROM generate_series(TIMESTAMP '2024-01-01', TIMESTAMP '2024-12-31', INTERVAL 1 DAY) AS t(d);

-- Факт: текст способа оплаты заменяем на id из dim_pay_method
INSERT INTO fact_receipt_line
SELECT r.receipt_line_id::BIGINT, r.sold_at::TIMESTAMP,
       r.client_id::INTEGER, r.sku_id::INTEGER, r.shop_id::INTEGER,
       p.pay_method_id,
       r.qty::DECIMAL(10,1), r.sell_price::DECIMAL(10,2), r.line_total::DECIMAL(12,2)
FROM read_csv('data/raw/fact_receipt.csv', header = true, all_varchar = true) AS r
JOIN dim_pay_method p ON p.pay_method = r.pay_method;
