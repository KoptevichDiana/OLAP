SELECT 'fact_receipt_line' AS table_name,
       (SELECT COUNT(*) FROM fact_receipt_line) AS rows_db,
       (SELECT COUNT(*) FROM read_csv('data/raw/fact_receipt.csv', header = true, all_varchar = true)) AS rows_csv
UNION ALL SELECT 'fact_supply',
       (SELECT COUNT(*) FROM fact_supply),
       (SELECT COUNT(*) FROM read_csv('data/raw/fact_supply.csv', header = true, all_varchar = true))
UNION ALL SELECT 'fact_writeoff',
       (SELECT COUNT(*) FROM fact_writeoff),
       (SELECT COUNT(*) FROM read_csv('data/raw/fact_writeoff.csv', header = true, all_varchar = true))
UNION ALL SELECT 'dim_goods',
       (SELECT COUNT(*) FROM dim_goods),
       (SELECT COUNT(*) FROM read_csv('data/raw/dim_goods.csv', header = true, all_varchar = true))
UNION ALL SELECT 'dim_client',
       (SELECT COUNT(*) FROM dim_client),
       (SELECT COUNT(*) FROM read_csv('data/raw/dim_client.csv', header = true, all_varchar = true))
UNION ALL SELECT 'dim_shop',
       (SELECT COUNT(*) FROM dim_shop),
       (SELECT COUNT(*) FROM read_csv('data/raw/dim_shop.csv', header = true, all_varchar = true))
UNION ALL SELECT 'dim_calendar',
       (SELECT COUNT(*) FROM dim_calendar),
       (SELECT COUNT(*) FROM read_csv('data/raw/dim_date.csv', header = true, all_varchar = true))
UNION ALL SELECT 'dim_supplier',
       (SELECT COUNT(*) FROM dim_supplier),
       (SELECT COUNT(*) FROM read_csv('data/raw/dim_supplier.csv', header = true, all_varchar = true))
UNION ALL SELECT 'dim_transport',
       (SELECT COUNT(*) FROM dim_transport),
       (SELECT COUNT(*) FROM read_csv('data/raw/dim_transport.csv', header = true, all_varchar = true))
UNION ALL SELECT 'dim_writeoff_reason',
       (SELECT COUNT(*) FROM dim_writeoff_reason),
       (SELECT COUNT(*) FROM read_csv('data/raw/dim_writeoff_reason.csv', header = true, all_varchar = true))
UNION ALL SELECT 'dim_pay_method', (SELECT COUNT(*) FROM dim_pay_method), NULL;

SELECT 'fact_receipt_line' AS fact,
       COUNT(*) FILTER (WHERE client_id IS NULL OR sku_id IS NULL OR shop_id IS NULL
                           OR pay_method_id IS NULL OR sold_at IS NULL) AS null_keys
FROM fact_receipt_line
UNION ALL
SELECT 'fact_supply',
       COUNT(*) FILTER (WHERE supplier_id IS NULL OR shop_id IS NULL OR sku_id IS NULL
                           OR transport_id IS NULL OR delivered_at IS NULL)
FROM fact_supply
UNION ALL
SELECT 'fact_writeoff',
       COUNT(*) FILTER (WHERE shop_id IS NULL OR sku_id IS NULL OR supply_id IS NULL
                           OR reason_id IS NULL OR written_off_at IS NULL)
FROM fact_writeoff;

SELECT 'fact_receipt_line' AS fact, COUNT(*) AS orphan_date
FROM fact_receipt_line f
LEFT JOIN dim_calendar c ON c.date_key = CAST(f.sold_at AS DATE)
WHERE c.date_key IS NULL
UNION ALL
SELECT 'fact_supply', COUNT(*)
FROM fact_supply f
LEFT JOIN dim_calendar c ON c.date_key = CAST(f.delivered_at AS DATE)
WHERE c.date_key IS NULL
UNION ALL
SELECT 'fact_writeoff', COUNT(*)
FROM fact_writeoff f
LEFT JOIN dim_calendar c ON c.date_key = CAST(f.written_off_at AS DATE)
WHERE c.date_key IS NULL;

SELECT 'выручка' AS metric, COUNT(*) AS rows_cnt, SUM(line_total) AS amount,
       COUNT(*) FILTER (WHERE ABS(line_total - qty * sell_price) > 0.01) AS bad_rows
FROM fact_receipt_line
UNION ALL
SELECT 'закупка', COUNT(*), SUM(supply_amount),
       COUNT(*) FILTER (WHERE ABS(supply_amount - qty * purchase_price) > 0.01)
FROM fact_supply
UNION ALL
SELECT 'утилизация', COUNT(*), SUM(w.cost_amount),
       COUNT(*) FILTER (WHERE ABS(w.cost_amount - w.qty * s.purchase_price) > 0.01)
FROM fact_writeoff w
JOIN fact_supply s ON s.supply_id = w.supply_id;

SELECT COUNT(*) AS writeoffs,
       COUNT(*) FILTER (WHERE w.sku_id <> s.sku_id OR w.shop_id <> s.shop_id) AS other_goods_or_shop,
       COUNT(*) FILTER (WHERE w.written_off_at < s.delivered_at) AS before_delivery
FROM fact_writeoff w
JOIN fact_supply s ON s.supply_id = w.supply_id;

SELECT p.pay_method, COUNT(*) AS cnt, SUM(f.line_total) AS revenue
FROM fact_receipt_line f
JOIN dim_pay_method p ON p.pay_method_id = f.pay_method_id
GROUP BY p.pay_method
ORDER BY cnt DESC;

SELECT 'продажи' AS fact, MIN(sold_at) AS first_at, MAX(sold_at) AS last_at
FROM fact_receipt_line
UNION ALL
SELECT 'поставки (привоз)', MIN(delivered_at), MAX(delivered_at)
FROM fact_supply
UNION ALL
SELECT 'утилизация', MIN(written_off_at), MAX(written_off_at)
FROM fact_writeoff;
