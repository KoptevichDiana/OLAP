SELECT sum(line_total) AS revenue
FROM olap.fact_receipt_line;

SELECT sum(line_total) AS revenue_march
FROM olap.fact_receipt_line
WHERE sold_at >= '2024-03-01' AND sold_at < '2024-04-01';

SELECT sum(line_total) AS revenue_march_shop1
FROM olap.fact_receipt_line
WHERE sold_at >= '2024-03-01' AND sold_at < '2024-04-01' AND shop_id = 1;
