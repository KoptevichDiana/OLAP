# P03. Таблицы в DuckDB

**Домен:** D1 — розница (сеть из 12 продуктовых магазинов, 2024 год)

**ФИО:** Коптевич Диана Витальевна, Дудич Даниил Сергеевич, Шмурей Кирилл Сергеевич  
**Группа:** ИИ-231

Таблицы созданы по паспорту P02: **3 факта + 8 измерений**.

## Структура

```text
P03/
├── data/raw/                 # CSV из P01 (те же 10 файлов)
├── sql/
│   ├── ddl_duckdb.sql        # создание таблиц
│   └── load_duckdb.sql       # загрузка CSV → таблицы
├── load_data.py              # запускает DDL → загрузку → проверки
├── checks.sql                # проверочные запросы
├── checks.txt                # сохранённый вывод проверок
├── README.md
└── retail.duckdb             # база, создаётся скриптом
```

## Факты

| Таблица | Одна строка = | Ключ | Источник |
|---------|---------------|------|----------|
| `fact_receipt_line` | одна строка чека | `receipt_line_id` | `fact_receipt.csv` |
| `fact_supply` | одна партия товара, привезённая в магазин | `supply_id` | `fact_supply.csv` |
| `fact_writeoff` | одно списание товара из партии | `writeoff_id` | `fact_writeoff.csv` |

## Измерения

| Таблица | Одна строка = | Ключ | Источник |
|---------|---------------|------|----------|
| `dim_goods` | один товар | `sku_id` | `dim_goods.csv` |
| `dim_client` | один клиент | `client_id` | `dim_client.csv` |
| `dim_shop` | один магазин | `shop_id` | `dim_shop.csv` |
| `dim_calendar` | один день 2024 года | `date_key` | `dim_date.csv` |
| `dim_supplier` | один поставщик | `supplier_id` | `dim_supplier.csv` |
| `dim_transport` | один вид транспорта | `transport_id` | `dim_transport.csv` |
| `dim_writeoff_reason` | одна причина утилизации | `reason_id` | `dim_writeoff_reason.csv` |
| `dim_pay_method` | один способ оплаты | `pay_method_id` | 4 значения из `fact_receipt.csv` |

## Связи

| Факт | Поле | Куда ведёт |
|------|------|------------|
| все три | `sku_id` | `dim_goods` |
| все три | `shop_id` | `dim_shop` |
| продажи | `client_id`, `pay_method_id` | `dim_client`, `dim_pay_method` |
| поставки | `supplier_id`, `transport_id` | `dim_supplier`, `dim_transport` |
| утилизация | `reason_id`, `supply_id` | `dim_writeoff_reason`, `fact_supply` |
| товар | `vendor_id` | `dim_supplier` |

Все связи — `FOREIGN KEY`. С календарём факты связаны по дате: продажи — `sold_at`, поставки — `delivered_at` (дата привоза), утилизация — `written_off_at`. Отгрузка `shipped_at` у первых поставок приходится на конец декабря 2023, а календарь только на 2024 год, поэтому поставки привязаны к дате привоза.

Деньги (`list_price`, `sell_price`, `line_total`, `purchase_price`, `supply_amount`, `cost_amount`) — `DECIMAL`, не `FLOAT`. Пустые КБЖУ у бытовой химии и чая загружаются как `NULL`.

## Как загрузить

### 1. Установить DuckDB (один раз)

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install duckdb
```

### 2. Запустить из папки P03

```bash
cd P03
python load_data.py
```

Скрипт:
- пересоздаёт таблицы из `sql/ddl_duckdb.sql`;
- грузит CSV из `data/raw/` через `sql/load_duckdb.sql` — сначала справочники, потом факты;
- выполняет `checks.sql`;
- печатает всё на экран и сохраняет в `checks.txt`.

## Повторный запуск

`DROP TABLE` + `CREATE TABLE` в начале DDL: таблицы каждый раз создаются пустыми, поэтому факты не удваиваются. Ключи фактов — `PRIMARY KEY`, дубль строки DuckDB не пропустит.

## Итог проверок

| Проверка | Результат |
|----------|-----------|
| строк в фактах | продажи 25 000, поставки 25 000, утилизация 3 002 — совпадает с CSV |
| строк в справочниках | товары 25 000, клиенты 25 000, магазины 12, календарь 366, поставщики 300, транспорт 6, причины 6, способы оплаты 4 |
| пустые ключи в фактах | 0 |
| даты без пары в календаре | 0 |
| списания не из той партии / раньше привоза | 0 / 0 |
| **выручка `SUM(line_total)`** | **15 383 068.36** (совпадает с P01) |
| закупка `SUM(supply_amount)` | 12 542 717.29 |
| утилизация `SUM(cost_amount)` | 425 223.01 |

Полный вывод — `checks.txt`.
