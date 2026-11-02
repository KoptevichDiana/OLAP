from pathlib import Path
import duckdb

root = Path(__file__).resolve().parents[1]
raw = root / "data" / "raw"
db = root / "retail_local.duckdb"
con = duckdb.connect(str(db))

TABLES = ["dim_goods", "dim_client", "dim_shop", "dim_date", "dim_supplier",
          "dim_transport", "dim_writeoff_reason",
          "fact_receipt", "fact_supply", "fact_writeoff"]

for name in TABLES:
    path = (raw / f"{name}.csv").as_posix()
    con.execute(f"CREATE OR REPLACE TABLE {name} AS SELECT * FROM read_csv_auto('{path}')").fetchall()
    n = con.execute(f"SELECT count(*) FROM {name}").fetchall()[0][0]
    print(f"{name}: {n} строк")


def total(sql):
    return con.execute(sql).fetchall()[0][0]


print("Итого:")
print("  выручка (продажи):  ", total("SELECT round(sum(line_total), 2) FROM fact_receipt"))
print("  закупка (поставки): ", total("SELECT round(sum(supply_amount), 2) FROM fact_supply"))
print("  утилизация:         ", total("SELECT round(sum(cost_amount), 2) FROM fact_writeoff"))

print("Утилизация по причинам:")
for name, cnt, amount in con.execute("""
    SELECT r.reason_name, count(*), round(sum(w.cost_amount), 2)
    FROM fact_writeoff w JOIN dim_writeoff_reason r USING (reason_id)
    GROUP BY 1 ORDER BY 3 DESC
""").fetchall():
    print(f"  {name}: {cnt} списаний, {amount}")

print("OK →", db)
