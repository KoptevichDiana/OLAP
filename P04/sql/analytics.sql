-- ============================================================
-- З04. Аналитический SQL
-- Три запроса — ответы на три бизнес-вопроса из паспорта P02.
-- Таблицы — из P03 (retail.duckdb).
-- ============================================================


-- ------------------------------------------------------------
-- Вопрос 1: Какой отдел дал наибольшую выручку в каждом квартале 2024 года?
-- GROUP BY (квартал + отдел) + ОКНА:
--   RANK() OVER (PARTITION BY quarter) — место отдела внутри квартала,
--   SUM() OVER (PARTITION BY quarter)  — доля отдела в выручке квартала.
-- ------------------------------------------------------------
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


-- ------------------------------------------------------------
-- Вопрос 2: Сколько выручки приходится на клиентов с картой лояльности
--           и без неё, по магазинам?
-- GROUP BY по магазину + условные суммы (FILTER)
-- ------------------------------------------------------------
SELECT
    s.shop_name,
    SUM(f.line_total) FILTER (WHERE cl.is_loyal)     AS loyal_revenue,
    SUM(f.line_total) FILTER (WHERE NOT cl.is_loyal) AS not_loyal_revenue,
    SUM(f.line_total)                                AS total_revenue,
    ROUND(100.0 * SUM(f.line_total) FILTER (WHERE cl.is_loyal)
                / SUM(f.line_total), 2)              AS loyal_share_pct
FROM fact_receipt_line f
JOIN dim_client cl ON cl.client_id = f.client_id
JOIN dim_shop   s  ON s.shop_id    = f.shop_id
GROUP BY s.shop_id, s.shop_name
ORDER BY s.shop_id;


-- ------------------------------------------------------------
-- Вопрос 3: Как меняется доля оплат через СБП по месяцам?
-- GROUP BY по месяцу + ОКНО LAG() — изменение доли к прошлому месяцу.
-- Доля считается по числу строк чека.
-- ------------------------------------------------------------
WITH m AS (
    SELECT
        c.month,
        c.month_name,
        COUNT(*)                                     AS lines_all,
        COUNT(*) FILTER (WHERE p.pay_method = 'СБП') AS lines_sbp
    FROM fact_receipt_line f
    JOIN dim_calendar   c ON c.date_key      = CAST(f.sold_at AS DATE)
    JOIN dim_pay_method p ON p.pay_method_id = f.pay_method_id
    WHERE c.year = 2024
    GROUP BY c.month, c.month_name
)
SELECT
    month,
    month_name,
    lines_all,
    lines_sbp,
    ROUND(100.0 * lines_sbp / lines_all, 2) AS sbp_share_pct,
    ROUND(100.0 * lines_sbp / lines_all
        - LAG(100.0 * lines_sbp / lines_all) OVER (ORDER BY month), 2) AS change_pp
FROM m
ORDER BY month;
