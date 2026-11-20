# OLAP-витрина продуктового ритейла

**ФИО:** Коптевич Диана Витальевна, Дудич Даниил Сергеевич, Шмурей Кирилл Сергеевич  
**Группа:** ИИ-231  
**Домен:** сеть из 12 продуктовых магазинов, 2024 год — поставка → продажа → утилизация.

Нужны Docker, Python 3.10+ и Git. Все команды — из корня репозитория.

## Запуск за 5 шагов

### 1. Docker и стенд

Один раз положить драйвер ClickHouse для Metabase (`clickhouse.metabase-driver.jar`, релиз 1.52.x) в `P01/metabase/plugins/`, подробнее — `P10/README.md`.

```bash
cd P01 && docker compose up -d && cd ..
curl http://localhost:8123/ping
```

Ответ `Ok.` — ClickHouse поднят, Metabase стартует на порту 3000.

### 2. Загрузка данных

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install duckdb clickhouse-driver
cd P05 && python etl/load_data.py && cd ..
python3 P07/etl/load_all.py
docker exec -i olap_clickhouse clickhouse-client --multiquery < P09/sql/summary_ddl.sql
docker exec -i olap_clickhouse clickhouse-client --multiquery < P09/sql/summary_fill.sql
```

`P05` проверяет CSV и собирает `P05/retail.duckdb`, `P07` переносит 11 таблиц в ClickHouse (база `olap`) и сверяет строки и суммы, `P09` пересобирает сводку под графики. Повторный запуск не задваивает данные.

### 3. Эталонный SQL метрики

Эталон — `P04/sql/canonical_metric.sql`, в ClickHouse тот же запрос — `P10/dashboards/widget1_revenue.sql`:

```bash
docker exec olap_clickhouse clickhouse-client --query "SELECT sum(line_total) FROM olap.fact_receipt_line"
```

Ожидаемо: **15383068.36**.

### 4. Дашборд

<http://localhost:3000> → дашборд «Продуктовый ритейл 2024». Подключение к ClickHouse: host `clickhouse`, port `8123`, user `default`, пароль пустой, база `olap`.  
SQL всех карточек — `P10/dashboards/`, сверка карточки с SQL — `P11/notes/z11.md`.

### 5. Если что-то красное

| Симптом | Куда смотреть |
|---------|---------------|
| `/ping` не отвечает | `docker compose -f P01/docker-compose.yml ps`, `docker logs olap_clickhouse` |
| `load_data.py` упал | вывод скрипта и `P05/run_log.txt` — какая проверка не прошла |
| `load_all.py` пишет `FAIL` | сравнить с `P07/notes/load_log.txt` |
| в Metabase нет типа ClickHouse | драйвер не лежит в `P01/metabase/plugins/`, `docker logs olap_metabase` |
| карточка ≠ 15 383 068.36 | не пуст ли фильтр «Период», пересобрана ли сводка (шаг 2), см. `P11/notes/z11.md` |

### Что делается руками

- драйвер Metabase для ClickHouse скачивается вручную;
- на чистом стенде дашборд собирается в Metabase вручную по SQL из `P10/dashboards/` (Metabase хранит его в томе `mb_data`, см. `cut.md`).

## Путь данных (устный рассказ)

Исходные CSV (`P05/data/raw`, 3 факта + 7 справочников) → скрипт `P05/etl/load_data.py` проверяет обязательные поля, дубли, связи и календарь и собирает витрину в DuckDB → `P07/etl/load_all.py` переносит её в ClickHouse: сначала справочники, потом факты, каждая таблица `TRUNCATE` + `INSERT`, после загрузки сверка `count()` и денежных сумм с DuckDB. Факт продаж хранится с `ORDER BY (sold_at, shop_id, receipt_line_id)`: отчёты фильтруют по периоду и магазину, поэтому дата и магазин стоят первыми, а номер строки чека замыкает сортировку (`ORDER BY` — не уникальный ключ, от дублей защищает перезаливка). Для графиков `P09` строит сводку `sales_by_shop_day` (одна строка = день × магазин). Эталонный SQL метрики — `SUM(line_total)` по детальному факту, он же стоит в карточке «Выручка сети» на дашборде с тем же фильтром «Период»; на весь 2024 год оба показывают 15 383 068.36.

**Одна строка факта** `fact_receipt_line` = одна строка чека (один товар, проданный одному клиенту в одном магазине в один момент).  
**Главная мера** = `line_total` — выручка строки (`qty × sell_price`), в `Decimal(12,2)`.

## Структура

| Папка | Что внутри |
|-------|------------|
| `P01` | стенд: docker compose (ClickHouse + Metabase), сырьё |
| `P02` | схема «звезда», паспорт, первый cut |
| `P03`, `P05` | загрузка и проверки в DuckDB |
| `P04` | аналитический SQL и эталон метрики |
| `P06` | SCD2 для `dim_goods` |
| `P07` | загрузка в ClickHouse и сверка |
| `P08` | ключ сортировки, партиция, аналитика в ClickHouse |
| `P09` | сводная таблица под график |
| `P10` | дашборд Metabase |
| `P11` | сверка SQL и карточки |
| `P12` | этот README, чеклист, актуальный `cut.md` |
