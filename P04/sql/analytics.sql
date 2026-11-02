WITH dept_q AS (
    SELECT
        c.quarter,
        g.dept,
        SUM(f.line_total) AS revenue
    FROM fact_receipt_line f
    JOIN dim_goods    g ON g.sku_id   = f.sku_id
    JOIN dim_calendar c ON c.date_key = CAST(f.sold_at AS DATE)
    WHERE c.year = 2024
    GROUP BY c.quarter, g.dept
)
SELECT
    quarter,
    RANK() OVER (PARTITION BY quarter ORDER BY revenue DESC)              AS place,
    dept,
    revenue,
    ROUND(100.0 * revenue / SUM(revenue) OVER (PARTITION BY quarter), 2) AS share_pct
FROM dept_q
ORDER BY quarter, place;


WITH by_reason AS (
    SELECT
        g.dept,
        r.reason_name,
        COUNT(*)           AS cnt,
        SUM(w.cost_amount) AS cost
    FROM fact_writeoff w
    JOIN dim_goods           g ON g.sku_id    = w.sku_id
    JOIN dim_writeoff_reason r ON r.reason_id = w.reason_id
    GROUP BY g.dept, r.reason_name
),
by_dept AS (
    SELECT
        dept,
        reason_name,
        cost,
        SUM(cnt)  OVER (PARTITION BY dept)                    AS writeoffs_cnt,
        SUM(cost) OVER (PARTITION BY dept)                    AS writeoff_cost,
        ROW_NUMBER() OVER (PARTITION BY dept ORDER BY cost DESC) AS rn
    FROM by_reason
),
supply AS (
    SELECT
        g.dept,
        SUM(s.supply_amount) AS supply_cost
    FROM fact_supply s
    JOIN dim_goods g ON g.sku_id = s.sku_id
    GROUP BY g.dept
)
SELECT
    d.dept,
    d.writeoffs_cnt,
    d.writeoff_cost,
    s.supply_cost,
    ROUND(100.0 * d.writeoff_cost / s.supply_cost, 2) AS writeoff_rate_pct,
    d.reason_name                                     AS main_reason,
    ROUND(100.0 * d.cost / d.writeoff_cost, 2)        AS main_reason_pct
FROM by_dept d
JOIN supply s ON s.dept = d.dept
WHERE d.rn = 1
ORDER BY d.writeoff_cost DESC;


SELECT
    t.transport_name,
    t.is_refrigerated,
    COUNT(*)                                                                AS supplies_cnt,
    ROUND(AVG(date_diff('minute', f.shipped_at, f.delivered_at)) / 60.0, 1) AS avg_delivery_hours,
    SUM(f.supply_amount)                                                    AS supply_cost,
    ROUND(100.0 * SUM(f.supply_amount) / SUM(SUM(f.supply_amount)) OVER (), 2) AS supply_share_pct
FROM fact_supply f
JOIN dim_transport t ON t.transport_id = f.transport_id
GROUP BY t.transport_id, t.transport_name, t.is_refrigerated
ORDER BY avg_delivery_hours DESC;


SELECT
    SUM(f.supply_amount) FILTER (WHERE t.is_refrigerated) AS refrigerated_cost,
    SUM(f.supply_amount)                                  AS supply_cost,
    ROUND(100.0 * SUM(f.supply_amount) FILTER (WHERE t.is_refrigerated)
                / SUM(f.supply_amount), 2)                AS refrigerated_share_pct
FROM fact_supply f
JOIN dim_transport t ON t.transport_id = f.transport_id;
