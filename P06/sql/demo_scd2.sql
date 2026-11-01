-- З06. Демо SCD2: у товара меняется отдел.
-- Товар sku_id = 14224 «Кофе Makfa 500 г v8»: до июля 2024 был в отделе «Бакалея»,
-- с 1 июля 2024 его перенесли в отдел «Напитки».

-- Шаг 1. Начальные версии всех товаров (действуют с начала 2024 года)
INSERT INTO dim_goods_scd2
SELECT sku_id, item_name, dept, maker, measure_unit, list_price, vendor_id,
       DATE '2024-01-01', DATE '9999-12-31', TRUE
FROM dim_goods;

-- Шаг 2. Закрываем старую версию товара
UPDATE dim_goods_scd2
SET valid_to   = DATE '2024-07-01',
    is_current = FALSE
WHERE sku_id = 14224
  AND is_current;

-- Шаг 3. Добавляем новую текущую версию с отделом «Напитки»
INSERT INTO dim_goods_scd2
SELECT sku_id, item_name, 'Напитки', maker, measure_unit, list_price, vendor_id,
       DATE '2024-07-01', DATE '9999-12-31', TRUE
FROM dim_goods
WHERE sku_id = 14224;

-- Вывод 1: две версии одного товара
SELECT sku_id, item_name, dept, valid_from, valid_to, is_current
FROM dim_goods_scd2
WHERE sku_id = 14224
ORDER BY valid_from;

-- Вывод 2: продажи товара попадают в версию, действовавшую на дату продажи
SELECT v.dept, v.valid_from, v.valid_to,
       COUNT(*)          AS lines_cnt,
       SUM(f.line_total) AS revenue
FROM fact_receipt_line f
JOIN dim_goods_scd2 v
  ON v.sku_id = f.sku_id
 AND CAST(f.sold_at AS DATE) >= v.valid_from
 AND CAST(f.sold_at AS DATE) <  v.valid_to
WHERE f.sku_id = 14224
GROUP BY v.dept, v.valid_from, v.valid_to
ORDER BY v.valid_from;

-- Вывод 3: проверка - выручка через SCD2 не потерялась и не задвоилась (должно быть 15383068.36)
SELECT (SELECT COUNT(*) FROM dim_goods_scd2)                AS versions,
       (SELECT COUNT(DISTINCT sku_id) FROM dim_goods_scd2)  AS goods,
       SUM(f.line_total)                                     AS revenue_scd2
FROM fact_receipt_line f
JOIN dim_goods_scd2 v
  ON v.sku_id = f.sku_id
 AND CAST(f.sold_at AS DATE) >= v.valid_from
 AND CAST(f.sold_at AS DATE) <  v.valid_to;
