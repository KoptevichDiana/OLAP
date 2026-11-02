from pathlib import Path
import duckdb

DB = Path("../P03/retail.duckdb")
FILES = {
    "sql/canonical_metric.sql": [
        "Главная метрика: выручка сети",
        "Вспомогательная метрика: доля утилизации от закупки",
    ],
    "sql/analytics.sql": [
        "Вопрос 1: Какой отдел дал наибольшую выручку в каждом квартале 2024 года?",
        "Вопрос 2: В каких отделах больше всего теряем на утилизации, по какой причине и какая это доля от закупки?",
        "Вопрос 3а: Сколько в среднем едет товар на каждом виде транспорта?",
        "Вопрос 3б: Какая часть закупки везётся в холодильнике?",
    ],
}

if not DB.exists():
    raise SystemExit(f"Нет базы {DB}. Сначала запустите P03/load_data.py")


def table(rel):
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

for file, titles in FILES.items():
    log.append(f"===== {file} =====")
    queries = [q.strip() for q in Path(file).read_text(encoding="utf-8").split(";") if q.strip()]
    for title, sql in zip(titles, queries):
        log.append("")
        log.append(f"-- {title}")
        log.append(table(con.sql(sql)))
    log.append("")

con.close()
out = "\n".join(log)
print(out)
Path("analytics_output.txt").write_text(out + "\n", encoding="utf-8")
print("Вывод сохранён в analytics_output.txt")
