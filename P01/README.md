# З01. Стенд и сырьё

**Домен:** D1 — розница (сеть из 12 продуктовых магазинов, 2024 год)

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

## Сырьё: 3 факта + 7 измерений

### Что описывают данные

| Процесс | Факт | Кто / что / где / когда / как |
|---------|------|-------------------------------|
| **Продажа** — товар продали покупателю | `fact_receipt` | **кому** `dim_client`, **что** `dim_goods`, **где** `dim_shop`, **когда** `dim_date` |
| **Поставка** (логистика) — товар привезли в магазин | `fact_supply` | **откуда** `dim_supplier`, **куда** `dim_shop`, **что** `dim_goods`, **как** `dim_transport`, **когда** `dim_date` |
| **Утилизация** — товар списали и выбросили | `fact_writeoff` | **что** `dim_goods`, **где** `dim_shop`, **почему** `dim_writeoff_reason`, **когда** `dim_date`, **из какой партии** `fact_supply` |

### Сводная таблица

| Файл | Тип | Строк | Поля |
|------|-----|-------|------|
| `fact_receipt.csv` | факт | 25 000 | receipt_line_id, sold_at, client_id, sku_id, qty, sell_price, line_total, pay_method, shop_id |
| `fact_supply.csv` | факт | 25 000 | supply_id, shipped_at, delivered_at, supplier_id, shop_id, sku_id, transport_id, qty, purchase_price, supply_amount, expiry_date |
| `fact_writeoff.csv` | факт | 3 002 | writeoff_id, written_off_at, shop_id, sku_id, supply_id, reason_id, qty, cost_amount |
| `dim_goods.csv` | измерение | 25 000 | sku_id, item_name, dept, maker, measure_unit, list_price, vendor_id, description, kcal, protein_g, fat_g, carbs_g, shelf_life_days, storage_conditions |
| `dim_client.csv` | измерение | 25 000 | client_id, client_name, sex, birth_year, home_city, is_loyal, signup_date |
| `dim_shop.csv` | измерение | 12 | shop_id, shop_name, city, address, format, area_m2, open_date |
| `dim_date.csv` | измерение | 366 | date_key, year, quarter, month, month_name, day, weekday, weekday_name, is_weekend, is_holiday |
| `dim_supplier.csv` | измерение | 300 | supplier_id, supplier_name, supplier_type, city, contract_year |
| `dim_transport.csv` | измерение | 6 | transport_id, transport_name, body_type, capacity_t, is_refrigerated, temp_range |
| `dim_writeoff_reason.csv` | измерение | 6 | reason_id, reason_name, reason_group, is_supplier_fault |

---

## Факты

### fact_receipt.csv — продажи

Одна строка = одна строка чека.

| Поле | Расшифровка | Тип |
|------|-------------|-----|
| `receipt_line_id` | Уникальный идентификатор строки чека | INT (PK) |
| `sold_at` | Дата и время продажи | DATETIME |
| `client_id` | Кому продали (→ dim_client) | INT (FK) |
| `sku_id` | Что продали (→ dim_goods) | INT (FK) |
| `qty` | Количество (для весовых — дробное, кг) | DECIMAL |
| `sell_price` | Фактическая цена за единицу | DECIMAL |
| `line_total` | Сумма строки (qty × sell_price) | DECIMAL |
| `pay_method` | Способ оплаты (карта, наличные, СБП, подарочная карта) | VARCHAR |
| `shop_id` | Где продали (→ dim_shop) | INT (FK) |

### fact_supply.csv — поставки (логистика)

Одна строка = одна партия товара, которую поставщик привёз в магазин.

| Поле | Расшифровка | Тип |
|------|-------------|-----|
| `supply_id` | Уникальный идентификатор партии | INT (PK) |
| `shipped_at` | Когда отгрузили со склада поставщика | DATETIME |
| `delivered_at` | Когда привезли в магазин | DATETIME |
| `supplier_id` | Откуда (→ dim_supplier) | INT (FK) |
| `shop_id` | Куда (→ dim_shop) | INT (FK) |
| `sku_id` | Что привезли (→ dim_goods) | INT (FK) |
| `transport_id` | Как привезли (→ dim_transport) | INT (FK) |
| `qty` | Количество в партии | DECIMAL |
| `purchase_price` | Закупочная цена за единицу | DECIMAL |
| `supply_amount` | Стоимость партии (qty × purchase_price) | DECIMAL |
| `expiry_date` | Годен до (дата привоза + срок годности товара) | DATE |

### fact_writeoff.csv — утилизация

Одна строка = одно списание товара из партии.

| Поле | Расшифровка | Тип |
|------|-------------|-----|
| `writeoff_id` | Уникальный идентификатор списания | INT (PK) |
| `written_off_at` | Когда списали | DATETIME |
| `shop_id` | В каком магазине (→ dim_shop) | INT (FK) |
| `sku_id` | Что списали (→ dim_goods) | INT (FK) |
| `supply_id` | Из какой партии (→ fact_supply) | INT (FK) |
| `reason_id` | Почему списали (→ dim_writeoff_reason) | INT (FK) |
| `qty` | Сколько списали | DECIMAL |
| `cost_amount` | Потери по закупочной цене (qty × purchase_price партии) | DECIMAL |

---

## Измерения

### dim_goods.csv — товары (что)

| Поле | Расшифровка | Тип |
|------|-------------|-----|
| `sku_id` | Уникальный идентификатор товара | INT (PK) |
| `item_name` | Наименование | VARCHAR |
| `dept` | Отдел: бакалея, молочные, мясо и птица, напитки, овощи и фрукты, снеки и сладости, хлеб и выпечка, бытовая химия | VARCHAR |
| `maker` | Производитель | VARCHAR |
| `measure_unit` | Единица измерения (шт / кг) | VARCHAR |
| `list_price` | Цена по прайсу | DECIMAL |
| `vendor_id` | Поставщик (→ dim_supplier) | INT (FK) |
| `description` | Описание товара | VARCHAR |
| `kcal` | Калорийность, ккал на 100 г | INT |
| `protein_g` | Белки, г на 100 г | DECIMAL |
| `fat_g` | Жиры, г на 100 г | DECIMAL |
| `carbs_g` | Углеводы, г на 100 г | DECIMAL |
| `shelf_life_days` | Срок годности, дней | INT |
| `storage_conditions` | Условия хранения (температура и т.п.) | VARCHAR |

У бытовой химии и чая КБЖУ пустые: это непищевой товар / энергетическая ценность незначительна.
Сроки годности: от 2 дней (фарш, багет) до 5 лет (сахар, стиральный порошок).

### dim_client.csv — клиенты (кому)

| Поле | Расшифровка | Тип |
|------|-------------|-----|
| `client_id` | Уникальный идентификатор клиента | INT (PK) |
| `client_name` | Фамилия и имя | VARCHAR |
| `sex` | Пол (М / Ж) | VARCHAR |
| `birth_year` | Год рождения | INT |
| `home_city` | Город проживания | VARCHAR |
| `is_loyal` | Карта лояльности (1 — есть, 0 — нет) | TINYINT |
| `signup_date` | Дата регистрации в программе | DATE |

### dim_shop.csv — магазины (где / куда)

| Поле | Расшифровка | Тип |
|------|-------------|-----|
| `shop_id` | Номер магазина 1–12 | INT (PK) |
| `shop_name` | Название | VARCHAR |
| `city` | Город | VARCHAR |
| `address` | Адрес | VARCHAR |
| `format` | Формат: у дома / супермаркет / гипермаркет | VARCHAR |
| `area_m2` | Площадь, м² | INT |
| `open_date` | Дата открытия | DATE |

### dim_date.csv — календарь (когда)

| Поле | Расшифровка | Тип |
|------|-------------|-----|
| `date_key` | Дата | DATE (PK) |
| `year`, `quarter`, `month`, `day` | Год, квартал, месяц, день | INT |
| `month_name` | Название месяца | VARCHAR |
| `weekday` | День недели (1 — пн … 7 — вс) | INT |
| `weekday_name` | Название дня недели | VARCHAR |
| `is_weekend` | Выходной (сб, вс) | TINYINT |
| `is_holiday` | Праздник (новогодние, 23.02, 8.03, 1.05, 9.05, 12.06, 4.11) | TINYINT |

### dim_supplier.csv — поставщики (откуда)

| Поле | Расшифровка | Тип |
|------|-------------|-----|
| `supplier_id` | Идентификатор поставщика (= `vendor_id` в товарах) | INT (PK) |
| `supplier_name` | Название | VARCHAR |
| `supplier_type` | Дистрибьютор / оптовая база | VARCHAR |
| `city` | Город склада | VARCHAR |
| `contract_year` | Год заключения договора | INT |

### dim_transport.csv — транспорт (как привезли)

| Поле | Расшифровка | Тип |
|------|-------------|-----|
| `transport_id` | Идентификатор | INT (PK) |
| `transport_name` | Тип машины (рефрижератор, фура, фургон, хлебный фургон) | VARCHAR |
| `body_type` | Фура / фургон | VARCHAR |
| `capacity_t` | Грузоподъёмность, т | DECIMAL |
| `is_refrigerated` | С охлаждением (1 — да) | TINYINT |
| `temp_range` | Температурный режим | VARCHAR |

### dim_writeoff_reason.csv — причины утилизации (почему)

| Поле | Расшифровка | Тип |
|------|-------------|-----|
| `reason_id` | Идентификатор | INT (PK) |
| `reason_name` | Причина: истёк срок годности, порча, нарушение температуры, повреждение упаковки, брак, повреждение при перевозке | VARCHAR |
| `reason_group` | Группа причины | VARCHAR |
| `is_supplier_fault` | Виноват поставщик (1 — да, можно вернуть деньги) | TINYINT |

---

## Как связаны данные

- Под каждую продажу есть партия поставки того же товара в тот же магазин: привезли **до** продажи, срок годности истекает **после** продажи.
- Поставщик партии — тот же, что указан у товара (`vendor_id`).
- Охлаждённые товары (молочка, мясо) везут рефрижератором, хлеб — хлебным фургоном, остальное — фурой или фургоном.
- Утилизация — из остатка партии (привезли больше, чем продали). Скоропорт чаще всего списывается в день окончания срока годности.

## Главные суммы

| Показатель | Значение |
|------------|----------|
| Выручка (`fact_receipt.line_total`) | 15 383 068.36 |
| Закупка (`fact_supply.supply_amount`) | 12 542 717.29 |
| Утилизация (`fact_writeoff.cost_amount`) | 425 223.01 (≈ 2,8 % от выручки) |

## Доказательство

См. `proof.txt`.
