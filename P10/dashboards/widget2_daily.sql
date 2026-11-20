SELECT
    sale_date,
    sum(revenue) AS revenue
FROM olap.sales_by_shop_day
WHERE 1 = 1
[[AND {{period}}]]
GROUP BY sale_date
ORDER BY sale_date
