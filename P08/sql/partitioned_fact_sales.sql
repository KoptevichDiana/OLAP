-- P08. Партиционированная копия факта продаж из P07.
-- Исходная olap.fact_receipt_line остаётся без изменений.
-- CREATE ... AS наследует структуру столбцов исходной таблицы.
CREATE TABLE IF NOT EXISTS olap.fact_receipt_line_partitioned
AS olap.fact_receipt_line
ENGINE = MergeTree
PARTITION BY toYYYYMM(sold_at)
ORDER BY (sold_at, shop_id, receipt_line_id);

-- Повторный запуск не добавляет дубли.
TRUNCATE TABLE olap.fact_receipt_line_partitioned;
INSERT INTO olap.fact_receipt_line_partitioned
SELECT * FROM olap.fact_receipt_line;

-- Сверка количества строк и главной метрики.
SELECT 'original' AS source, count() AS rows_count, sum(line_total) AS revenue
FROM olap.fact_receipt_line
UNION ALL
SELECT 'partitioned' AS source, count() AS rows_count, sum(line_total) AS revenue
FROM olap.fact_receipt_line_partitioned;

-- Партиции по месяцам: результат зависит от фактического состояния сервера.
SELECT partition, sum(rows) AS rows_count,
       formatReadableSize(sum(bytes_on_disk)) AS size
FROM system.parts
WHERE database = 'olap'
  AND table = 'fact_receipt_line_partitioned'
  AND active
GROUP BY partition
ORDER BY partition;
