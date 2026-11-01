"""
З06. Создаёт dim_goods_scd2 и прогоняет демо смены отдела у товара.
Работает на базе из P05 (../P05/retail.duckdb), вывод сохраняет в scd2_output.txt.

Запуск из папки P06/ (сначала должен быть выполнен P05/etl/load_data.py):
    python run_scd2.py
"""
from pathlib import Path
import duckdb

DB = Path("../P05/retail.duckdb")

if not DB.exists():
    raise SystemExit(f"Нет базы {DB}. Сначала запустите P05/etl/load_data.py")


def table(rel):
    """Печатает результат целиком, без обрезки строк и колонок."""
    cols = rel.columns
    rows = [["NULL" if v is None else str(v) for v in r] for r in rel.fetchall()]
    w = [max(len(c), *(len(r[i]) for r in rows)) if rows else len(c) for i, c in enumerate(cols)]
    line = "+-" + "-+-".join("-" * x for x in w) + "-+"
    out = [line, "| " + " | ".join(c.ljust(x) for c, x in zip(cols, w)) + " |", line]
    out += ["| " + " | ".join(v.rjust(x) for v, x in zip(r, w)) + " |" for r in rows]
    out += [line, f"({len(rows)} rows)"]
    return "\n".join(out)


con = duckdb.connect(str(DB))
log = []

con.execute(Path("sql/ddl_scd2.sql").read_text(encoding="utf-8"))

text = Path("sql/demo_scd2.sql").read_text(encoding="utf-8")
for block in text.split(";"):
    lines = block.strip().splitlines()
    sql = "\n".join(l for l in lines if not l.strip().startswith("--")).strip()
    if not sql:
        continue
    if sql.upper().startswith("SELECT"):
        title = next((l for l in lines if l.startswith("-- Вывод")), "")
        log.append(title)
        log.append(table(con.sql(sql)))
        log.append("")
    else:
        con.execute(sql)

con.close()
out = "\n".join(log)
print(out)
Path("scd2_output.txt").write_text(out + "\n", encoding="utf-8")
print("Вывод сохранён в scd2_output.txt")
