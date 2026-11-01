"""
З04. Прогоняет sql/canonical_metric.sql и sql/analytics.sql
на базе из P03 и сохраняет вывод в analytics_output.txt.

Запуск из папки P04/ (сначала должен быть выполнен P03/load_data.py):
    python run_analytics.py
"""
from pathlib import Path
import duckdb

DB = Path("../P03/retail.duckdb")
FILES = ["sql/canonical_metric.sql", "sql/analytics.sql"]

if not DB.exists():
    raise SystemExit(f"Нет базы {DB}. Сначала запустите P03/load_data.py")

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


con = duckdb.connect(str(DB), read_only=True)
log = []

for file in FILES:
    log.append(f"===== {file} =====")
    text = Path(file).read_text(encoding="utf-8")
    for block in text.split(";"):
        lines = block.strip().splitlines()
        sql = "\n".join(l for l in lines if not l.strip().startswith("--")).strip()
        if not sql:
            continue
        title = next((l for l in lines if l.startswith("-- Вопрос")), "-- Главная метрика")
        log.append("")
        log.append(title)
        log.append(table(con.sql(sql)))
    log.append("")

con.close()
out = "\n".join(log)
print(out)
Path("analytics_output.txt").write_text(out + "\n", encoding="utf-8")
print("Вывод сохранён в analytics_output.txt")
