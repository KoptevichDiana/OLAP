# Сверка DuckDB ↔ ClickHouse

В ClickHouse перенесены те же данные, что находятся в `P05/retail.duckdb`. После каждой загрузки скрипт сравнивает `count(*)` всех таблиц и суммы основных денежных показателей.

## Count

| Таблица | DuckDB | ClickHouse |
|---|---:|---:|
| dim_supplier | 300 | 300 |
| dim_goods | 25 000 | 25 000 |
| dim_client | 25 000 | 25 000 |
| dim_shop | 12 | 12 |
| dim_calendar | 366 | 366 |
| dim_pay_method | 4 | 4 |
| dim_transport | 6 | 6 |
| dim_writeoff_reason | 6 | 6 |
| fact_receipt_line | 25 000 | 25 000 |
| fact_supply | 25 000 | 25 000 |
| fact_writeoff | 3 002 | 3 002 |

Все 11 таблиц совпадают по количеству строк.

## Главная метрика

Эталонная метрика — выручка от продаж:

```sql
-- DuckDB
SELECT SUM(line_total) FROM fact_receipt_line;

-- ClickHouse
SELECT SUM(line_total) FROM olap.fact_receipt_line;
```

| База | Выручка |
|---|---:|
| DuckDB | 15 383 068.36 |
| ClickHouse | 15 383 068.36 |

Выручка совпадает до копейки. Дополнительно сверены расходы по поставкам и списаниям:

| Показатель | DuckDB | ClickHouse |
|---|---:|---:|
| `SUM(supply_amount)` из `fact_supply` | 12 542 717.29 | 12 542 717.29 |
| `SUM(cost_amount)` из `fact_writeoff` | 425 223.01 | 425 223.01 |

## Повторная загрузка

Загрузка выполнена дважды подряд командой `python3 etl/load_all.py all --twice`. Лог обоих прогонов — в `notes/load_log.txt`. После второго прогона число строк в `fact_receipt_line` осталось **25 000** (не 50 000), а выручка — **15 383 068.36**. Дубли не накапливаются, поскольку перед каждой загрузкой таблицы очищаются командой `TRUNCATE TABLE` и заполняются заново.
