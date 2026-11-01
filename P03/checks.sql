-- З03. Проверки после загрузки. Сеть продуктовых магазинов.

-- 1. Строк в таблицах и в CSV (должно совпадать)
SELECT 'fact_receipt_line' AS table_name,
       (SELECT COUNT(*) FROM fact_receipt_line) AS rows_db,
       (SELECT COUNT(*) FROM read_csv('data/raw/fact_receipt.csv', header = true, all_varchar = true)) AS rows_csv
UNION ALL SELECT 'dim_goods',
       (SELECT COUNT(*) FROM dim_goods),
       (SELECT COUNT(*) FROM read_csv('data/raw/dim_goods.csv', header = true, all_varchar = true))
UNION ALL SELECT 'dim_client',
       (SELECT COUNT(*) FROM dim_client),
       (SELECT COUNT(*) FROM read_csv('data/raw/dim_client.csv', header = true, all_varchar = true))
UNION ALL SELECT 'dim_shop',       (SELECT COUNT(*) FROM dim_shop),       NULL
UNION ALL SELECT 'dim_pay_method', (SELECT COUNT(*) FROM dim_pay_method), NULL
UNION ALL SELECT 'dim_calendar',   (SELECT COUNT(*) FROM dim_calendar),   NULL;

-- 2. Пустые ключи в факте (должно быть 0)
SELECT
    COUNT(*) FILTER (WHERE client_id     IS NULL) AS null_client,
    COUNT(*) FILTER (WHERE sku_id        IS NULL) AS null_sku,
    COUNT(*) FILTER (WHERE shop_id       IS NULL) AS null_shop,
    COUNT(*) FILTER (WHERE pay_method_id IS NULL) AS null_pay,
    COUNT(*) FILTER (WHERE sold_at       IS NULL) AS null_date
FROM fact_receipt_line;

-- 3. Дата продажи без пары в календаре (должно быть 0)
SELECT COUNT(*) AS orphan_date
FROM fact_receipt_line f
LEFT JOIN dim_calendar c ON c.date_key = CAST(f.sold_at AS DATE)
WHERE c.date_key IS NULL;

-- 4. Главная мера: выручка (в P01 было 15383068.36)
SELECT
    COUNT(*)        AS lines_cnt,
    SUM(line_total) AS revenue,
    COUNT(*) FILTER (WHERE ABS(line_total - qty * sell_price) > 0.01) AS bad_lines
FROM fact_receipt_line;

-- 5. Строки по способам оплаты
SELECT p.pay_method, COUNT(*) AS cnt, SUM(f.line_total) AS revenue
FROM fact_receipt_line f
JOIN dim_pay_method p USING (pay_method_id)
GROUP BY p.pay_method
ORDER BY cnt DESC;

-- 6. Период продаж
SELECT MIN(sold_at) AS first_sale, MAX(sold_at) AS last_sale
FROM fact_receipt_line;
