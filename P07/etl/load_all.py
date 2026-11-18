import argparse
from decimal import Decimal
from pathlib import Path
import duckdb
from create_tables import connect, main as create_tables

ROOT = Path(__file__).resolve().parents[1]
DB_CANDIDATES = [ROOT.parent / "P05" / "retail.duckdb", ROOT.parent / "P03" / "retail.duckdb"]
GROUPS = {
    "sales": ["dim_supplier", "dim_goods", "dim_client", "dim_shop", "dim_calendar", "dim_pay_method", "fact_receipt_line"],
    "logistics": ["dim_transport", "fact_supply"],
    "writeoffs": ["dim_writeoff_reason", "fact_writeoff"],
}
ALL_TABLES = list(dict.fromkeys(t for ts in GROUPS.values() for t in ts))

def get_db_path():
    for path in DB_CANDIDATES:
        if path.exists():
            return path
    raise FileNotFoundError("Не найдена P05/retail.duckdb или P03/retail.duckdb рядом с P07")

def load_group(duck, ch, group):
    print(f"--- group: {group} ---")
    for table in GROUPS[group]:
        # Полный refresh: MergeTree не гарантирует уникальность строк при INSERT.
        ch.execute(f"TRUNCATE TABLE olap.{table}")
        columns = [row[1] for row in duck.execute(f"PRAGMA table_info('{table}')").fetchall()]
        rows = duck.execute(f"SELECT * FROM {table}").fetchall()
        if rows:
            ch.execute(f"INSERT INTO olap.{table} ({', '.join(columns)}) VALUES", rows, types_check=True)
        source = duck.execute(f"SELECT count(*) FROM {table}").fetchone()[0]
        target = ch.execute(f"SELECT count(*) FROM olap.{table}")[0][0]
        print(f"{table:<22} DuckDB={source:<8} ClickHouse={target:<8} {'OK' if source == target else 'FAIL'}")
        if source != target:
            raise RuntimeError(f"Разное количество строк: {table}")

def check_metric(duck, ch):
    metrics = {"revenue": ("fact_receipt_line", "line_total"),
               "supply_cost": ("fact_supply", "supply_amount"),
               "writeoff_cost": ("fact_writeoff", "cost_amount")}
    for name, (table, column) in metrics.items():
        expected = duck.execute(f"SELECT SUM({column}) FROM {table}").fetchone()[0]
        actual = ch.execute(f"SELECT SUM({column}) FROM olap.{table}")[0][0]
        print(f"{name}: DuckDB={expected}; ClickHouse={actual}; {'OK' if expected == actual else 'FAIL'}")
        if expected != actual:
            raise RuntimeError(f"Расхождение метрики {name}")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("group", nargs="?", default="all", choices=["all", *GROUPS])
    parser.add_argument("--twice", action="store_true", help="Повторить загрузку и проверить отсутствие дублей")
    args = parser.parse_args()
    db = get_db_path()
    print("Источник:", db)
    create_tables()
    duck = duckdb.connect(str(db), read_only=True)
    ch = connect()
    selected = list(GROUPS) if args.group == "all" else [args.group]
    try:
        for run in range(2 if args.twice else 1):
            print(f"\n===== LOAD {run + 1} =====")
            for group in selected:
                load_group(duck, ch, group)
            if args.group == "all":
                check_metric(duck, ch)
        print("\nDone. Проверка завершена.")
    finally:
        duck.close()
        ch.disconnect()

if __name__ == "__main__":
    main()
