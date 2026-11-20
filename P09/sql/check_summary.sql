SELECT 'detail' AS source, count() AS lines_cnt, sum(line_total) AS revenue
FROM olap.fact_receipt_line
UNION ALL
SELECT 'summary' AS source, sum(lines_cnt) AS lines_cnt, sum(revenue) AS revenue
FROM olap.sales_by_shop_day;

SELECT 'detail' AS source, sum(line_total) AS revenue_march
FROM olap.fact_receipt_line
WHERE sold_at >= '2024-03-01' AND sold_at < '2024-04-01'
UNION ALL
SELECT 'summary' AS source, sum(revenue) AS revenue_march
FROM olap.sales_by_shop_day
WHERE sale_date BETWEEN '2024-03-01' AND '2024-03-31';

SELECT 'detail' AS source, sum(line_total) AS revenue_march_shop1
FROM olap.fact_receipt_line
WHERE sold_at >= '2024-03-01' AND sold_at < '2024-04-01' AND shop_id = 1
UNION ALL
SELECT 'summary' AS source, sum(revenue) AS revenue_march_shop1
FROM olap.sales_by_shop_day
WHERE sale_date BETWEEN '2024-03-01' AND '2024-03-31' AND shop_id = 1;

SELECT count() AS summary_rows
FROM olap.sales_by_shop_day;
