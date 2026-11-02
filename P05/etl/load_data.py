import sys
from datetime import datetime
from pathlib import Path
import duckdb

DB = "retail.duckdb"
RAW = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("data/raw")
LOG = Path("run_log.txt")
DIMS = ["dim_goods", "dim_client", "dim_shop", "dim_pay_method", "dim_calendar"]
FACT = "fact_receipt_line"

# Проверки качества: (название, SQL с числом плохих строк). Должно быть 0.
CHECKS = [
    ("пустые ключи и суммы в факте", """
        SELECT COUNT(*) FROM stg_receipt
        WHERE receipt_line_id IS NULL OR sold_at IS NULL OR client_id IS NULL
           OR sku_id IS NULL OR shop_id IS NULL OR pay_method IS NULL
           OR qty IS NULL OR line_total IS NULL"""),
    ("пустые ключи в справочниках", """
        SELECT (SELECT COUNT(*) FROM stg_goods  WHERE sku_id IS NULL OR dept IS NULL)
             + (SELECT COUNT(*) FROM stg_client WHERE client_id IS NULL)"""),
    ("странный диапазон: qty или суммы < 0", """
        SELECT COUNT(*) FROM stg_receipt
        WHERE TRY_CAST(qty AS DECIMAL(10,1)) < 0
           OR TRY_CAST(sell_price AS DECIMAL(10,2)) < 0
           OR TRY_CAST(line_total AS DECIMAL(12,2)) < 0"""),
    ("странный диапазон: дата не из 2024 года", """
        SELECT COUNT(*) FROM stg_receipt
        WHERE TRY_CAST(sold_at AS TIMESTAMP) IS NULL
           OR year(TRY_CAST(sold_at AS TIMESTAMP)) <> 2024"""),
    ("дубли receipt_line_id в факте", """
        SELECT COUNT(*) FROM (
            SELECT receipt_line_id FROM stg_receipt
            GROUP BY receipt_line_id HAVING COUNT(*) > 1)"""),
    ("дубли ключей в справочниках", """
        SELECT (SELECT COUNT(*) FROM (SELECT sku_id FROM stg_goods
                                      GROUP BY sku_id HAVING COUNT(*) > 1))
             + (SELECT COUNT(*) FROM (SELECT client_id FROM stg_client
                                      GROUP BY client_id HAVING COUNT(*) > 1))"""),
    ("сироты: товара нет в справочнике", """
        SELECT COUNT(*) FROM stg_receipt r
        LEFT JOIN stg_goods g ON g.sku_id = r.sku_id
        WHERE g.sku_id IS NULL"""),
    ("сироты: клиента нет в справочнике", """
        SELECT COUNT(*) FROM stg_receipt r
        LEFT JOIN stg_client c ON c.client_id = r.client_id
        WHERE c.client_id IS NULL"""),
    ("сироты: магазина нет в справочнике (1–12)", """
        SELECT COUNT(*) FROM stg_receipt
        WHERE TRY_CAST(shop_id AS INTEGER) IS NULL
           OR TRY_CAST(shop_id AS INTEGER) NOT BETWEEN 1 AND 12"""),
]

log = []


def say(text=""):
    print(text)
    log.append(str(text))


def save_log():
    with LOG.open("a", encoding="utf-8") as f:
        f.write("\n".join(log) + "\n\n")


def stop(msg, changed=False):
    say(f"СТОП: {msg}")
    say("Витрина могла измениться, нужна повторная загрузка." if changed
        else "Загрузка остановлена, витрина не изменялась.")
    save_log()
    raise SystemExit(1)


def main():
    say("=" * 60)
    say(f"Прогон {datetime.now():%Y-%m-%d %H:%M:%S}, источник: {RAW}")
    say("=" * 60)

    for f in ("dim_goods.csv", "dim_client.csv", "fact_receipt.csv"):
        if not (RAW / f).exists():
            stop(f"нет файла {RAW / f}")

    con = duckdb.connect(DB)
    con.execute(Path("sql/ddl_duckdb.sql").read_text(encoding="utf-8"))

    # 1. CSV → stg
    say("1) CSV → промежуточные таблицы stg_*")
    for stg, file in [("stg_goods", "dim_goods.csv"), ("stg_client", "dim_client.csv"),
                      ("stg_receipt", "fact_receipt.csv")]:
        path = (RAW / file).as_posix()
        con.execute(f"CREATE OR REPLACE TEMP TABLE {stg} AS "
                    f"SELECT * FROM read_csv('{path}', header = true, all_varchar = true)")
        n = con.execute(f"SELECT COUNT(*) FROM {stg}").fetchall()[0][0]
        say(f"   {stg:<12} {n:>8,} строк")

    # 2. Проверки качества
    say("2) Проверки качества")
    failed = 0
    for title, sql in CHECKS:
        bad = con.execute(sql).fetchall()[0][0]
        say(f"   {'OK  ' if bad == 0 else 'FAIL'} {title}: {bad}")
        if bad:
            failed += 1
    if failed:
        con.close()
        stop(f"не прошло проверок: {failed}")

    # 3. Очистка витрины: факт → справочники
    say("3) Очистка витрины (факт → справочники)")
    con.execute(f"DELETE FROM {FACT}")
    for t in reversed(DIMS):
        con.execute(f"DELETE FROM {t}")

    # 4. Заполнение: справочники → факт
    say("4) Заполнение (справочники → факт)")
    con.execute(Path("sql/load_duckdb.sql").read_text(encoding="utf-8"))
    for t in DIMS + [FACT]:
        n = con.execute(f"SELECT COUNT(*) FROM {t}").fetchall()[0][0]
        say(f"   {t:<18} {n:>8,} строк")

    # 5. Сверка с CSV
    rows_csv, sum_csv = con.execute(
        "SELECT COUNT(*), SUM(line_total::DECIMAL(12,2)) FROM stg_receipt").fetchall()[0]
    rows_dw, sum_dw = con.execute(
        f"SELECT COUNT(*), SUM(line_total) FROM {FACT}").fetchall()[0]
    say("5) Сверка факта с CSV")
    say(f"   строк:   CSV {rows_csv:,} | витрина {rows_dw:,}")
    say(f"   выручка: CSV {sum_csv} | витрина {sum_dw}")
    con.close()
    if rows_csv != rows_dw or sum_csv != sum_dw:
        stop("факт не совпадает с CSV", changed=True)

    say(f"ИТОГ: fact_receipt_line = {rows_dw:,} строк, SUM(line_total) = {sum_dw}")
    save_log()
    print(f"\nГотово. База: {DB}, лог дописан в {LOG}")


if __name__ == "__main__":
    main()
