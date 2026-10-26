"""Smoke-тест DuckDB: те же CSV из data/raw, что грузятся в ClickHouse."""
from pathlib import Path
import duckdb

root = Path(__file__).resolve().parents[1]
raw = root / "data" / "raw"
db = root / "retail_local.duckdb"
con = duckdb.connect(str(db))

for name in ("dim_goods", "dim_client", "fact_receipt"):
    path = (raw / f"{name}.csv").as_posix()
    con.execute(f"CREATE OR REPLACE TABLE {name} AS SELECT * FROM read_csv_auto('{path}')")
    n = con.execute(f"SELECT count(*) FROM {name}").fetchone()[0]
    print(f"{name}: {n} строк")

rows = con.execute(
    """
    SELECT g.dept, round(sum(f.line_total), 2) AS revenue
    FROM fact_receipt f
    JOIN dim_goods g ON f.sku_id = g.sku_id
    GROUP BY 1
    ORDER BY 2 DESC
    """
).fetchall()
print("Выручка по отделам:")
for dept, revenue in rows:
    print(f"  {dept}: {revenue}")

total = con.execute("SELECT round(sum(line_total), 2) FROM fact_receipt").fetchone()[0]
print("Итого:", total)
print("OK →", db)
