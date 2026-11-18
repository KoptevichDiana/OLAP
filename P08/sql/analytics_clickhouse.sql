-- P08. Аналитические запросы ClickHouse по витрине продуктового ритейла.
-- Эталон P04: sql/canonical_metric.sql, сумма line_total.

-- 1. Главная метрика: общая выручка.
SELECT sum(line_total) AS revenue
FROM olap.fact_receipt_line;

-- 2. P04: рейтинг отделов по кварталам 2024 года.
WITH dept_q AS (
    SELECT
        c.quarter AS quarter,
        g.dept AS dept,
        sum(f.line_total) AS revenue
    FROM olap.fact_receipt_line AS f
    INNER JOIN olap.dim_goods AS g ON g.sku_id = f.sku_id
    INNER JOIN olap.dim_calendar AS c ON c.date_key = toDate(f.sold_at)
    WHERE c.year = 2024
    GROUP BY c.quarter, g.dept
)
SELECT
    quarter,
    rank() OVER (PARTITION BY quarter ORDER BY revenue DESC) AS place,
    dept,
    revenue,
    round(100.0 * revenue / sum(revenue) OVER (PARTITION BY quarter), 2) AS share_pct
FROM dept_q
ORDER BY quarter, place, dept;

-- 3. P04: стоимость и причины списаний по отделам.
WITH by_reason AS (
    SELECT
        g.dept AS dept,
        r.reason_name AS reason_name,
        count() AS cnt,
        sum(w.cost_amount) AS cost
    FROM olap.fact_writeoff AS w
    INNER JOIN olap.dim_goods AS g ON g.sku_id = w.sku_id
    INNER JOIN olap.dim_writeoff_reason AS r ON r.reason_id = w.reason_id
    GROUP BY g.dept, r.reason_name
),
by_dept AS (
    SELECT
        dept,
        reason_name,
        cost,
        sum(cnt) OVER (PARTITION BY dept) AS writeoffs_cnt,
        sum(cost) OVER (PARTITION BY dept) AS writeoff_cost,
        row_number() OVER (PARTITION BY dept ORDER BY cost DESC, reason_name) AS rn
    FROM by_reason
),
supply AS (
    SELECT
        g.dept AS dept,
        sum(s.supply_amount) AS supply_cost
    FROM olap.fact_supply AS s
    INNER JOIN olap.dim_goods AS g ON g.sku_id = s.sku_id
    GROUP BY g.dept
)
SELECT
    d.dept,
    d.writeoffs_cnt,
    d.writeoff_cost,
    s.supply_cost,
    round(100.0 * d.writeoff_cost / nullIf(s.supply_cost, 0), 2) AS writeoff_rate_pct,
    d.reason_name AS main_reason,
    round(100.0 * d.cost / nullIf(d.writeoff_cost, 0), 2) AS main_reason_pct
FROM by_dept AS d
INNER JOIN supply AS s ON s.dept = d.dept
WHERE d.rn = 1
ORDER BY d.writeoff_cost DESC;
