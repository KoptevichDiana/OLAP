# Дизайн загрузки

## Группы таблиц

11 таблиц витрины продуктового ритейла разбиты на 3 бизнес-группы. При загрузке отдельной группы обновляются только её таблицы, остальные не затрагиваются.

| Группа | Таблицы |
|---|---|
| sales | dim_supplier, dim_goods, dim_client, dim_shop, dim_calendar, dim_pay_method, fact_receipt_line |
| logistics | dim_transport, fact_supply |
| writeoffs | dim_writeoff_reason, fact_writeoff |

Загрузить одну группу: `python3 etl/load_all.py sales` (или `logistics`, `writeoffs`).  
Загрузить всё: `python3 etl/load_all.py all`.  
Загрузить всё дважды с проверкой: `python3 etl/load_all.py all --twice`.

## Порядок хранения и ключи

Все таблицы созданы на `MergeTree`. Поле `ORDER BY` задаёт физический порядок хранения и помогает отбирать данные по условиям запроса. **Это не уникальный ключ**, ClickHouse не запрещает вставить две строки с одинаковым значением.

| Таблица | ORDER BY |
|---|---|
| dim_supplier | supplier_id |
| dim_goods | sku_id |
| dim_client | client_id |
| dim_shop | shop_id |
| dim_calendar | date_key |
| dim_pay_method | pay_method_id |
| dim_transport | transport_id |
| dim_writeoff_reason | reason_id |
| fact_receipt_line | sold_at, shop_id, receipt_line_id |
| fact_supply | shipped_at, shop_id, supply_id |
| fact_writeoff | written_off_at, shop_id, writeoff_id |

Для продаж первыми стоят дата и магазин, поскольку отчёты анализируют выручку по периодам и торговым точкам. В поставках и списаниях порядок также начинается с даты события и магазина, что удобно для временных срезов. Идентификатор события завершает сортировку фактов. Справочники сортируются по собственным идентификаторам для удобства поиска по ключу.

Денежные поля (`line_total`, `sell_price`, `supply_amount`, `purchase_price`, `cost_amount` и др.) хранятся как `Decimal`, чтобы избежать ошибок округления при сверке.

## Как работает защита от дублей

Используется **полная перезагрузка выбранных таблиц**: сначала `TRUNCATE TABLE`, затем `INSERT` из DuckDB. Поэтому при успешном повторном запуске количество строк остаётся прежним; новые копии строк не накапливаются. В отличие от `ReplacingMergeTree`, здесь не используется `FINAL` и не предполагается фоновое удаление дублей.

Такой способ подходит для учебной витрины, но на время перезагрузки таблица может быть пустой; при сбое между очисткой и вставкой потребуется повторить загрузку.

## Проверка

Данные загружены два раза подряд командой `python3 etl/load_all.py all --twice`. Сверка строк и денежных показателей приведена в `notes/reconciliation.md`, вывод обоих прогонов — в `notes/load_log.txt`.
