SELECT
    shop_name,
    sum(revenue) AS revenue
FROM olap.sales_by_shop_day
WHERE 1 = 1
[[AND {{period}}]]
GROUP BY shop_name
ORDER BY revenue DESC
