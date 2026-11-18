import os
import re
from pathlib import Path
from clickhouse_driver import Client
ROOT = Path(__file__).resolve().parents[1]

def connect():
    return Client(host=os.getenv("CH_HOST", "localhost"), port=int(os.getenv("CH_PORT", "9000")),
                  user=os.getenv("CH_USER", "default"), password=os.getenv("CH_PASSWORD", ""))

def main():
    client = connect()
    script = (ROOT / "sql" / "ddl_clickhouse.sql").read_text(encoding="utf-8")
    script = re.sub(r"--[^\n]*", "", script)
    for statement in script.split(";"):
        if statement.strip():
            client.execute(statement.strip())
            print("OK:", statement.strip().splitlines()[0])

if __name__ == "__main__":
    main()
