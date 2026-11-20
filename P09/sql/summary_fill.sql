TRUNCATE TABLE olap.sales_by_shop_day;

INSERT INTO olap.sales_by_shop_day
SELECT
    toDate(f.sold_at) AS sale_date,
    f.shop_id,
    s.shop_name,
    s.city,
    sum(f.line_total) AS revenue,
    count() AS lines_cnt
FROM olap.fact_receipt_line AS f
INNER JOIN olap.dim_shop AS s ON s.shop_id = f.shop_id
GROUP BY sale_date, f.shop_id, s.shop_name, s.city;
