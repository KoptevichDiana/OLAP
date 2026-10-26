# З01. Стенд и сырьё

**Домен:** D1 — розница

**ФИО:** 

Коптевич Диана Витальевна

Дудич Даниил Сергеевич

Шмурей Кирилл Сергеевич
**Группа:** ИИ-231

## Как поднять ClickHouse

Из папки `P01/`:

    cd P01
    docker compose up -d
    chmod +x scripts/init_ch.sh
    ./scripts/init_ch.sh
    curl http://localhost:8123/ping     # → Ok.

## Проверка DuckDB

    python3 -m venv .venv
    source .venv/bin/activate
    pip install duckdb
    python scripts/duckdb_smoke.py

## Порты

| Сервис | Порт |
|--------|------|
| ClickHouse | 8123 |
| ClickHouse | 9000 |
| Metabase | 3000 |

## Сырьё

### Сводная таблица

| Файл | Строк | Поля |
|------|-------|------|
| `dim_goods.csv` | 25 000 | sku_id, item_name, dept, maker, measure_unit, list_price, vendor_id |
| `dim_client.csv` | 25 000 | client_id, client_name, sex, birth_year, home_city, is_loyal, signup_date |
| `fact_receipt.csv` | 25 000 | receipt_line_id, sold_at, client_id, sku_id, qty, sell_price, line_total, pay_method, shop_id |

---

### dim_client.csv

| Поле | Расшифровка | Тип |
|------|-------------|-----|
| `client_id` | Уникальный идентификатор клиента | INT (PK) |
| `client_name` | Фамилия и имя клиента | VARCHAR |
| `sex` | Пол (М / Ж) | VARCHAR |
| `birth_year` | Год рождения | INT |
| `home_city` | Город проживания | VARCHAR |
| `is_loyal` | Участие в программе лояльности (1 — да, 0 — нет) | TINYINT |
| `signup_date` | Дата регистрации в программе | DATE |

---

### dim_goods.csv

| Поле | Расшифровка | Тип |
|------|-------------|-----|
| `sku_id` | Уникальный идентификатор товарной позиции | INT (PK) |
| `item_name` | Наименование товара | VARCHAR |
| `dept` | Товарный отдел (категория) | VARCHAR |
| `maker` | Производитель | VARCHAR |
| `measure_unit` | Единица измерения (шт / кг) | VARCHAR |
| `list_price` | Прейскурантная цена | DECIMAL |
| `vendor_id` | Идентификатор поставщика | INT |

---

### fact_receipt.csv

| Поле | Расшифровка | Тип |
|------|-------------|-----|
| `receipt_line_id` | Уникальный идентификатор строки чека | INT (PK) |
| `sold_at` | Дата и время продажи | DATETIME |
| `client_id` | Клиент (ссылка на dim_client) | INT (FK) |
| `sku_id` | Товар (ссылка на dim_goods) | INT (FK) |
| `qty` | Количество (для весовых дробное) | DECIMAL |
| `sell_price` | Фактическая цена за единицу | DECIMAL |
| `line_total` | Сумма по строке чека (qty × sell_price) | DECIMAL |
| `pay_method` | Способ оплаты | VARCHAR |
| `shop_id` | Номер магазина (1–12) | INT |

---

## Доказательство

См. `proof.txt`.
