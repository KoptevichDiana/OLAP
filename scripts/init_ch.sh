#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CH_HTTP="${CH_HTTP:-http://localhost:8123}"

echo "Ждём ClickHouse..."
for i in $(seq 1 60); do
  curl -sf "$CH_HTTP/ping" >/dev/null && break
  sleep 1
  if [[ $i -eq 60 ]]; then echo "ClickHouse не ответил. Запущен ли docker compose?" >&2; exit 1; fi
done

echo "Создаём схему..."
docker exec -i olap_clickhouse clickhouse-client --multiquery < "$ROOT/init/01_schema.sql"

for t in dim_goods dim_client fact_receipt; do
  echo "Загружаем $t"
  docker exec -i olap_clickhouse clickhouse-client --query "INSERT INTO retail_dw.$t FORMAT CSVWithNames" < "$ROOT/data/raw/$t.csv"
done

echo "Количество строк:"
docker exec -i olap_clickhouse clickhouse-client --query "
SELECT 'dim_goods' AS t, count() AS c FROM retail_dw.dim_goods
UNION ALL SELECT 'dim_client', count() FROM retail_dw.dim_client
UNION ALL SELECT 'fact_receipt', count() FROM retail_dw.fact_receipt
FORMAT Pretty"
echo "OK: retail_dw готов."
