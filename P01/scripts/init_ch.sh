#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CH_HTTP="${CH_HTTP:-http://localhost:8123}"
TABLES="dim_goods dim_client dim_shop dim_date dim_supplier dim_transport dim_writeoff_reason fact_receipt fact_supply fact_writeoff"

echo "Ждём ClickHouse..."
for i in $(seq 1 60); do
  curl -sf "$CH_HTTP/ping" >/dev/null && break
  sleep 1
  if [[ $i -eq 60 ]]; then echo "ClickHouse не ответил. Запущен ли docker compose?" >&2; exit 1; fi
done

echo "Создаём схему..."
docker exec -i olap_clickhouse clickhouse-client --multiquery < "$ROOT/init/01_schema.sql"

for t in $TABLES; do
  echo "Загружаем $t"
  docker exec -i olap_clickhouse clickhouse-client --query "INSERT INTO retail_dw.$t FORMAT CSVWithNames" < "$ROOT/data/raw/$t.csv"
done

echo "Количество строк:"
Q=""
for t in $TABLES; do
  [[ -n "$Q" ]] && Q="$Q UNION ALL "
  Q="${Q}SELECT '$t' AS t, count() AS c FROM retail_dw.$t"
done
docker exec -i olap_clickhouse clickhouse-client --query "$Q FORMAT Pretty"

echo "Главные суммы:"
docker exec -i olap_clickhouse clickhouse-client --query "
SELECT 'выручка (продажи)'  AS metric, sum(line_total)    AS value FROM retail_dw.fact_receipt
UNION ALL SELECT 'закупка (поставки)', sum(supply_amount) FROM retail_dw.fact_supply
UNION ALL SELECT 'утилизация',          sum(cost_amount)   FROM retail_dw.fact_writeoff
FORMAT Pretty"
echo "OK: retail_dw готов."
