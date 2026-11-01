# P03. Таблицы в DuckDB

**Домен:** D1 — розница (сеть продуктовых магазинов)

**ФИО:** Коптевич Диана Витальевна, Дудич Даниил Сергеевич, Шмурей Кирилл Сергеевич  
**Группа:** ИИ-231

Таблицы созданы по паспорту P02 (схема «звезда»).  
**Одна строка `fact_receipt_line` = одна строка чека** (ключ `receipt_line_id`).

## Структура

```text
P03/
├── data/raw/                 # CSV из P01 (те же файлы)
│   ├── dim_goods.csv
│   ├── dim_client.csv
│   └── fact_receipt.csv
├── sql/
│   ├── ddl_duckdb.sql        # создание таблиц
│   └── load_duckdb.sql       # загрузка CSV → таблицы
├── load_data.py              # запускает DDL → загрузку → проверки
├── checks.sql                # проверочные запросы
├── checks.txt                # сохранённый вывод проверок
├── README.md
└── retail.duckdb             # база, создаётся скриптом
```

## Таблицы: 5 измерений + 1 факт

| Таблица | Одна строка = | Ключ | Источник |
|---------|---------------|------|----------|
| `dim_goods` | один товар | `sku_id` | `data/raw/dim_goods.csv` |
| `dim_client` | один клиент | `client_id` | `data/raw/dim_client.csv` |
| `dim_shop` | один магазин | `shop_id` | номера 1–12 из `fact_receipt.csv` |
| `dim_pay_method` | один способ оплаты | `pay_method_id` | 4 значения из `fact_receipt.csv` |
| `dim_calendar` | один день 2024 года | `date_key` | генерируется в SQL |
| `fact_receipt_line` | одна строка чека | `receipt_line_id` | `data/raw/fact_receipt.csv` |

Связи факта: `sku_id`, `client_id`, `shop_id`, `pay_method_id` — FOREIGN KEY на справочники; `CAST(sold_at AS DATE)` → `dim_calendar.date_key`.

Деньги (`list_price`, `sell_price`, `line_total`) — `DECIMAL`, не `FLOAT`.

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
- грузит CSV из `data/raw/` через `sql/load_duckdb.sql`;
- выполняет `checks.sql`;
- печатает всё на экран и сохраняет в `checks.txt`.

## Повторный запуск

`DROP TABLE` + `CREATE TABLE` в начале DDL: таблицы каждый раз создаются пустыми, поэтому факт не удваивается. Дополнительно `receipt_line_id` — PRIMARY KEY: дубль строки DuckDB не пропустит.

## Итог проверок

| Проверка | Результат |
|----------|-----------|
| строк в факте / в CSV | 25 000 / 25 000 |
| строк в `dim_goods` / `dim_client` | 25 000 / 25 000 |
| `dim_shop` / `dim_pay_method` / `dim_calendar` | 12 / 4 / 366 |
| пустые ключи в факте | 0 |
| даты без пары в календаре | 0 |
| **выручка `SUM(line_total)`** | **15 383 068.36** (совпадает с P01) |

Полный вывод — `checks.txt`.
