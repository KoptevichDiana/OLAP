SELECT SUM(line_total) AS revenue
FROM fact_receipt_line;

SELECT
    (SELECT SUM(cost_amount)   FROM fact_writeoff) AS writeoff_cost,
    (SELECT SUM(supply_amount) FROM fact_supply)   AS supply_cost,
    ROUND(100.0 * (SELECT SUM(cost_amount) FROM fact_writeoff)
                / (SELECT SUM(supply_amount) FROM fact_supply), 2) AS writeoff_rate_pct;
