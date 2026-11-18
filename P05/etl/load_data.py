import sys
from datetime import datetime
from pathlib import Path
import duckdb

# Запускать из корня P05: python etl/load_data.py [папка_с_CSV]
DB = Path("retail.duckdb")
RAW = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("data/raw")
LOG = Path("run_log.txt")

FILES = {
    "stg_dim_supplier": "dim_supplier.csv",
    "stg_dim_goods": "dim_goods.csv",
    "stg_dim_client": "dim_client.csv",
    "stg_dim_shop": "dim_shop.csv",
    "stg_dim_date": "dim_date.csv",
    "stg_fact_receipt": "fact_receipt.csv",
    "stg_dim_transport": "dim_transport.csv",
    "stg_dim_writeoff_reason": "dim_writeoff_reason.csv",
    "stg_fact_supply": "fact_supply.csv",
    "stg_fact_writeoff": "fact_writeoff.csv",
}

# Каждая проверка должна вернуть 0 проблемных строк.
CHECKS = [
    ("пустые обязательные поля в продажах", """
        SELECT COUNT(*) FROM stg_fact_receipt
        WHERE receipt_line_id IS NULL OR sold_at IS NULL OR client_id IS NULL
           OR sku_id IS NULL OR qty IS NULL OR sell_price IS NULL
           OR line_total IS NULL OR pay_method IS NULL OR shop_id IS NULL
    """),
    ("пустые обязательные поля в поставках", """
        SELECT COUNT(*) FROM stg_fact_supply
        WHERE supply_id IS NULL OR shipped_at IS NULL OR delivered_at IS NULL
           OR supplier_id IS NULL OR shop_id IS NULL OR sku_id IS NULL
           OR transport_id IS NULL OR qty IS NULL OR purchase_price IS NULL
           OR supply_amount IS NULL OR expiry_date IS NULL
    """),
    ("пустые обязательные поля в списаниях", """
        SELECT COUNT(*) FROM stg_fact_writeoff
        WHERE writeoff_id IS NULL OR written_off_at IS NULL OR shop_id IS NULL
           OR sku_id IS NULL OR supply_id IS NULL OR reason_id IS NULL
           OR qty IS NULL OR cost_amount IS NULL
    """),
    ("пустые ключи справочников", """
        SELECT
          (SELECT COUNT(*) FROM stg_dim_goods WHERE sku_id IS NULL OR item_name IS NULL OR dept IS NULL)
        + (SELECT COUNT(*) FROM stg_dim_client WHERE client_id IS NULL OR client_name IS NULL)
        + (SELECT COUNT(*) FROM stg_dim_shop WHERE shop_id IS NULL OR shop_name IS NULL)
        + (SELECT COUNT(*) FROM stg_dim_supplier WHERE supplier_id IS NULL OR supplier_name IS NULL)
        + (SELECT COUNT(*) FROM stg_dim_transport WHERE transport_id IS NULL OR transport_name IS NULL)
        + (SELECT COUNT(*) FROM stg_dim_writeoff_reason WHERE reason_id IS NULL OR reason_name IS NULL)
        + (SELECT COUNT(*) FROM stg_dim_date WHERE date_key IS NULL)
    """),
    ("отрицательные количества или суммы", """
        SELECT
          (SELECT COUNT(*) FROM stg_fact_receipt
             WHERE TRY_CAST(qty AS DECIMAL(10,1)) < 0
                OR TRY_CAST(sell_price AS DECIMAL(10,2)) < 0
                OR TRY_CAST(line_total AS DECIMAL(12,2)) < 0)
        + (SELECT COUNT(*) FROM stg_fact_supply
             WHERE TRY_CAST(qty AS DECIMAL(10,1)) < 0
                OR TRY_CAST(purchase_price AS DECIMAL(10,2)) < 0
                OR TRY_CAST(supply_amount AS DECIMAL(12,2)) < 0)
        + (SELECT COUNT(*) FROM stg_fact_writeoff
             WHERE TRY_CAST(qty AS DECIMAL(10,1)) < 0
                OR TRY_CAST(cost_amount AS DECIMAL(12,2)) < 0)
    """),
    ("некорректные даты или даты раньше 1900 года", """
        SELECT
          (SELECT COUNT(*) FROM stg_fact_receipt
             WHERE TRY_CAST(sold_at AS TIMESTAMP) IS NULL
                OR TRY_CAST(sold_at AS TIMESTAMP) < TIMESTAMP '1900-01-01')
        + (SELECT COUNT(*) FROM stg_fact_supply
             WHERE TRY_CAST(shipped_at AS TIMESTAMP) IS NULL
                OR TRY_CAST(delivered_at AS TIMESTAMP) IS NULL
                OR TRY_CAST(expiry_date AS DATE) IS NULL
                OR TRY_CAST(shipped_at AS TIMESTAMP) < TIMESTAMP '1900-01-01'
                OR TRY_CAST(delivered_at AS TIMESTAMP) < TIMESTAMP '1900-01-01')
        + (SELECT COUNT(*) FROM stg_fact_writeoff
             WHERE TRY_CAST(written_off_at AS TIMESTAMP) IS NULL
                OR TRY_CAST(written_off_at AS TIMESTAMP) < TIMESTAMP '1900-01-01')
    """),
    ("дубли первичных ключей в фактах", """
        SELECT
          (SELECT COUNT(*) FROM (SELECT receipt_line_id FROM stg_fact_receipt GROUP BY 1 HAVING COUNT(*) > 1))
        + (SELECT COUNT(*) FROM (SELECT supply_id FROM stg_fact_supply GROUP BY 1 HAVING COUNT(*) > 1))
        + (SELECT COUNT(*) FROM (SELECT writeoff_id FROM stg_fact_writeoff GROUP BY 1 HAVING COUNT(*) > 1))
    """),
    ("дубли ключей в справочниках", """
        SELECT
          (SELECT COUNT(*) FROM (SELECT sku_id FROM stg_dim_goods GROUP BY 1 HAVING COUNT(*) > 1))
        + (SELECT COUNT(*) FROM (SELECT client_id FROM stg_dim_client GROUP BY 1 HAVING COUNT(*) > 1))
        + (SELECT COUNT(*) FROM (SELECT shop_id FROM stg_dim_shop GROUP BY 1 HAVING COUNT(*) > 1))
        + (SELECT COUNT(*) FROM (SELECT supplier_id FROM stg_dim_supplier GROUP BY 1 HAVING COUNT(*) > 1))
        + (SELECT COUNT(*) FROM (SELECT transport_id FROM stg_dim_transport GROUP BY 1 HAVING COUNT(*) > 1))
        + (SELECT COUNT(*) FROM (SELECT reason_id FROM stg_dim_writeoff_reason GROUP BY 1 HAVING COUNT(*) > 1))
        + (SELECT COUNT(*) FROM (SELECT date_key FROM stg_dim_date GROUP BY 1 HAVING COUNT(*) > 1))
    """),
    ("сироты продаж: товар, клиент или магазин", """
        SELECT COUNT(*) FROM stg_fact_receipt r
        LEFT JOIN stg_dim_goods g ON TRY_CAST(r.sku_id AS INTEGER) = TRY_CAST(g.sku_id AS INTEGER)
        LEFT JOIN stg_dim_client c ON TRY_CAST(r.client_id AS INTEGER) = TRY_CAST(c.client_id AS INTEGER)
        LEFT JOIN stg_dim_shop s ON TRY_CAST(r.shop_id AS INTEGER) = TRY_CAST(s.shop_id AS INTEGER)
        WHERE g.sku_id IS NULL OR c.client_id IS NULL OR s.shop_id IS NULL
    """),
    ("сироты поставок: товар, магазин, поставщик или транспорт", """
        SELECT COUNT(*) FROM stg_fact_supply f
        LEFT JOIN stg_dim_goods g ON TRY_CAST(f.sku_id AS INTEGER) = TRY_CAST(g.sku_id AS INTEGER)
        LEFT JOIN stg_dim_shop s ON TRY_CAST(f.shop_id AS INTEGER) = TRY_CAST(s.shop_id AS INTEGER)
        LEFT JOIN stg_dim_supplier p ON TRY_CAST(f.supplier_id AS INTEGER) = TRY_CAST(p.supplier_id AS INTEGER)
        LEFT JOIN stg_dim_transport t ON TRY_CAST(f.transport_id AS INTEGER) = TRY_CAST(t.transport_id AS INTEGER)
        WHERE g.sku_id IS NULL OR s.shop_id IS NULL OR p.supplier_id IS NULL OR t.transport_id IS NULL
    """),
    ("сироты списаний: товар, магазин, партия или причина", """
        SELECT COUNT(*) FROM stg_fact_writeoff w
        LEFT JOIN stg_dim_goods g ON TRY_CAST(w.sku_id AS INTEGER) = TRY_CAST(g.sku_id AS INTEGER)
        LEFT JOIN stg_dim_shop s ON TRY_CAST(w.shop_id AS INTEGER) = TRY_CAST(s.shop_id AS INTEGER)
        LEFT JOIN stg_fact_supply p ON TRY_CAST(w.supply_id AS BIGINT) = TRY_CAST(p.supply_id AS BIGINT)
        LEFT JOIN stg_dim_writeoff_reason r ON TRY_CAST(w.reason_id AS INTEGER) = TRY_CAST(r.reason_id AS INTEGER)
        WHERE g.sku_id IS NULL OR s.shop_id IS NULL OR p.supply_id IS NULL OR r.reason_id IS NULL
    """),
    ("даты фактов отсутствуют в календаре", """
        SELECT
          (SELECT COUNT(*) FROM stg_fact_receipt f LEFT JOIN stg_dim_date d
             ON CAST(TRY_CAST(f.sold_at AS TIMESTAMP) AS DATE) = TRY_CAST(d.date_key AS DATE)
             WHERE d.date_key IS NULL)
        + (SELECT COUNT(*) FROM stg_fact_supply f LEFT JOIN stg_dim_date d
             ON CAST(TRY_CAST(f.delivered_at AS TIMESTAMP) AS DATE) = TRY_CAST(d.date_key AS DATE)
             WHERE d.date_key IS NULL)
        + (SELECT COUNT(*) FROM stg_fact_writeoff f LEFT JOIN stg_dim_date d
             ON CAST(TRY_CAST(f.written_off_at AS TIMESTAMP) AS DATE) = TRY_CAST(d.date_key AS DATE)
             WHERE d.date_key IS NULL)
    """),
    ("списание относится к той же партии, товару и магазину и не раньше привоза", """
        SELECT COUNT(*) FROM stg_fact_writeoff w
        JOIN stg_fact_supply s ON TRY_CAST(w.supply_id AS BIGINT) = TRY_CAST(s.supply_id AS BIGINT)
        WHERE TRY_CAST(w.sku_id AS INTEGER) <> TRY_CAST(s.sku_id AS INTEGER)
           OR TRY_CAST(w.shop_id AS INTEGER) <> TRY_CAST(s.shop_id AS INTEGER)
           OR TRY_CAST(w.written_off_at AS TIMESTAMP) < TRY_CAST(s.delivered_at AS TIMESTAMP)
    """),
]

TABLES = [
    "dim_supplier", "dim_goods", "dim_client", "dim_shop", "dim_calendar",
    "dim_pay_method", "dim_transport", "dim_writeoff_reason",
    "fact_receipt_line", "fact_supply", "fact_writeoff",
]
FACTS = ["fact_receipt_line", "fact_supply", "fact_writeoff"]
log_lines = []


def say(message=""):
    print(message)
    log_lines.append(str(message))


def save_log():
    with LOG.open("a", encoding="utf-8") as f:
        f.write("\n".join(log_lines) + "\n\n")


def stop(con, message):
    say(f"СТОП: {message}")
    say("Витрина не изменялась: проверка выполнена до очистки и загрузки.")
    con.close()
    save_log()
    raise SystemExit(1)


def main():
    say("=" * 68)
    say(f"Прогон {datetime.now():%Y-%m-%d %H:%M:%S}, источник: {RAW}")
    say("=" * 68)

    missing = [name for name in FILES.values() if not (RAW / name).is_file()]
    if missing:
        say("Не найдены файлы: " + ", ".join(missing))
        save_log()
        raise SystemExit(1)

    con = duckdb.connect(str(DB))
    say("1) CSV → промежуточные таблицы stg_*")
    for table, filename in FILES.items():
        csv_path = (RAW / filename).resolve().as_posix().replace("'", "''")
        con.execute(
            f"CREATE OR REPLACE TEMP TABLE {table} AS "
            f"SELECT * FROM read_csv('{csv_path}', header=true, all_varchar=true)"
        )
        count = con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
        say(f"   {table:<24} {count:>8,} строк")

    say("2) Проверки качества (0 = успешно)")
    failed = 0
    for title, sql in CHECKS:
        bad_count = con.execute(sql).fetchone()[0]
        say(f"   {'OK  ' if bad_count == 0 else 'FAIL'} {title}: {bad_count}")
        failed += bad_count != 0
    if failed:
        stop(con, f"не пройдено проверок: {failed}")

    # Контрольная метрика из P04 — до и после загрузки.
    csv_metrics = {
        "sales": con.execute("SELECT COUNT(*), SUM(TRY_CAST(line_total AS DECIMAL(12,2))) FROM stg_fact_receipt").fetchone(),
        "supply": con.execute("SELECT COUNT(*), SUM(TRY_CAST(supply_amount AS DECIMAL(12,2))) FROM stg_fact_supply").fetchone(),
        "writeoff": con.execute("SELECT COUNT(*), SUM(TRY_CAST(cost_amount AS DECIMAL(12,2))) FROM stg_fact_writeoff").fetchone(),
    }

    say("3) Пересоздание витрины и загрузка")
    try:
        con.execute("BEGIN TRANSACTION")
        con.execute(Path("sql/ddl_duckdb.sql").read_text(encoding="utf-8"))
        con.execute(Path("sql/load_duckdb.sql").read_text(encoding="utf-8"))
        for table in TABLES:
            count = con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
            say(f"   {table:<22} {count:>8,} строк")
        db_metrics = {
            "sales": con.execute("SELECT COUNT(*), SUM(line_total) FROM fact_receipt_line").fetchone(),
            "supply": con.execute("SELECT COUNT(*), SUM(supply_amount) FROM fact_supply").fetchone(),
            "writeoff": con.execute("SELECT COUNT(*), SUM(cost_amount) FROM fact_writeoff").fetchone(),
        }
        if csv_metrics != db_metrics:
            raise ValueError(f"сверка CSV и витрины не совпала: {csv_metrics} != {db_metrics}")
        con.execute("COMMIT")
    except Exception as exc:
        con.execute("ROLLBACK")
        con.close()
        say(f"ОШИБКА загрузки: {exc}")
        say("Транзакция отменена.")
        save_log()
        raise SystemExit(1)

    say("4) Сверка главных сумм с CSV")
    say(f"   продажи:   {db_metrics['sales'][0]:,} строк | выручка {db_metrics['sales'][1]}")
    say(f"   поставки:  {db_metrics['supply'][0]:,} строк | закупка {db_metrics['supply'][1]}")
    say(f"   списания:  {db_metrics['writeoff'][0]:,} строк | стоимость {db_metrics['writeoff'][1]}")
    say("ИТОГ: загрузка завершена успешно.")
    con.close()
    save_log()
    print(f"Лог дописан в {LOG}")


if __name__ == "__main__":
    main()
