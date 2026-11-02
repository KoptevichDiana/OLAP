from pathlib import Path
import duckdb

DB = "retail.duckdb"
RAW = Path("data/raw")
FILES = ["dim_goods", "dim_client", "dim_shop", "dim_date", "dim_supplier",
         "dim_transport", "dim_writeoff_reason",
         "fact_receipt", "fact_supply", "fact_writeoff"]
TABLES = ["dim_supplier", "dim_goods", "dim_client", "dim_shop", "dim_calendar",
          "dim_pay_method", "dim_transport", "dim_writeoff_reason",
          "fact_receipt_line", "fact_supply", "fact_writeoff"]
CHECKS = ["1. Строк в таблицах и в CSV (должно совпадать)",
          "2. Пустые ключи в фактах (должно быть 0)",
          "3. Даты без пары в календаре (должно быть 0)",
          "4. Главные суммы и проверка арифметики (bad_rows = 0)",
          "5. Списания совпадают с партией поставки (должно быть 0)",
          "6. Продажи по способам оплаты",
          "7. Период данных"]

log = []


def say(text=""):
    print(text)
    log.append(str(text))


def main():
    for f in FILES:
        if not (RAW / f"{f}.csv").exists():
            raise SystemExit(f"Нет файла {RAW / f}.csv. Скопируйте CSV из P01/data/raw/")

    con = duckdb.connect(DB)

    say("1) Создаём таблицы (sql/ddl_duckdb.sql) ...")
    con.execute(Path("sql/ddl_duckdb.sql").read_text(encoding="utf-8")).fetchall()

    say("2) Грузим CSV (sql/load_duckdb.sql) ...")
    con.execute(Path("sql/load_duckdb.sql").read_text(encoding="utf-8")).fetchall()
    for t in TABLES:
        n = con.execute(f"SELECT COUNT(*) FROM {t}").fetchall()[0][0]
        say(f"   {t:<20} {n:>8,} rows")

    say()
    say("3) Проверки (checks.sql)")
    queries = [q.strip() for q in Path("checks.sql").read_text(encoding="utf-8").split(";") if q.strip()]
    for title, sql in zip(CHECKS, queries):
        say()
        say(title)
        say(str(con.sql(sql)))

    con.close()
    Path("checks.txt").write_text("\n".join(log) + "\n", encoding="utf-8")
    print(f"\nГотово. База: {DB}, вывод сохранён в checks.txt")


if __name__ == "__main__":
    main()
