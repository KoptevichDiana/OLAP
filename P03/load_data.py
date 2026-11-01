"""
З03. Загрузка CSV из data/raw/ в DuckDB + проверки.
Сеть продуктовых магазинов, 6 таблиц (5 измерений + 1 факт).

Запуск из папки P03/:
    python load_data.py

Что делает:
  1) sql/ddl_duckdb.sql  — удаляет и заново создаёт таблицы (пустые);
  2) sql/load_duckdb.sql — грузит CSV;
  3) checks.sql          — выполняет проверки;
  всё печатает на экран и сохраняет в checks.txt.

Повторный запуск не удваивает факт: таблицы каждый раз создаются пустыми.
"""
from pathlib import Path
import duckdb

DB = "retail.duckdb"
RAW = Path("data/raw")
TABLES = ["dim_goods", "dim_client", "dim_shop", "dim_pay_method",
          "dim_calendar", "fact_receipt_line"]

log = []


def say(text=""):
    print(text)
    log.append(str(text))


def main():
    for f in ("dim_goods.csv", "dim_client.csv", "fact_receipt.csv"):
        if not (RAW / f).exists():
            raise SystemExit(f"Нет файла {RAW / f}. Скопируйте CSV из P01/data/raw/")

    con = duckdb.connect(DB)

    say("1) Создаём таблицы (sql/ddl_duckdb.sql) ...")
    con.execute(Path("sql/ddl_duckdb.sql").read_text(encoding="utf-8")).fetchall()

    say("2) Грузим CSV (sql/load_duckdb.sql) ...")
    con.execute(Path("sql/load_duckdb.sql").read_text(encoding="utf-8")).fetchall()
    for t in TABLES:
        n = con.execute(f"SELECT COUNT(*) FROM {t}").fetchall()[0][0]  # fetchall закрывает результат (нужно для DuckDB 2.0)
        say(f"   {t:<18} {n:>8,} rows")

    say()
    say("3) Проверки (checks.sql)")
    text = Path("checks.sql").read_text(encoding="utf-8")
    for block in text.split(";"):
        lines = block.strip().splitlines()
        sql = "\n".join(l for l in lines if not l.strip().startswith("--")).strip()
        if not sql:
            continue
        title = next((l for l in lines if l.startswith("-- ") and l[3:4].isdigit()), "")
        say()
        say(title)
        say(str(con.sql(sql)))

    con.close()
    Path("checks.txt").write_text("\n".join(log) + "\n", encoding="utf-8")
    print(f"\nГотово. База: {DB}, вывод сохранён в checks.txt")


if __name__ == "__main__":
    main()
