SELECT sum(line_total) AS revenue
FROM olap.fact_receipt_line
WHERE 1 = 1
[[AND {{period}}]]
