-- sql/canonical_metric.sql
-- Главная метрика: выручка сети = сумма line_total по всем строкам чеков.
-- Возвратов в сырье нет (отрицательных qty / line_total нет),
-- поэтому выручка = сумма всех продаж.
SELECT SUM(line_total) AS revenue
FROM fact_receipt_line;
