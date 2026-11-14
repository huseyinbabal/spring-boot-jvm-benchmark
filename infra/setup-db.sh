#!/usr/bin/env bash
# Database machine: Postgres 17 on the private IP only, postgres_exporter, node_exporter.  PRIV=<private ip> bash setup-db.sh
set -euo pipefail; source /root/common.sh
docker rm -f pg pgexp >/dev/null 2>&1 || true
docker run -d --name pg --restart=always --network host -e POSTGRES_DB=notes -e POSTGRES_USER=notes -e POSTGRES_PASSWORD=notes \
  -v pgdata:/var/lib/postgresql/data postgres:17 \
  -c listen_addresses="127.0.0.1,$PRIV" -c max_connections=200 -c shared_buffers=2GB -c effective_cache_size=6GB >/dev/null
docker run -d --name pgexp --restart=always --network host \
  -e DATA_SOURCE_NAME="postgresql://notes:notes@127.0.0.1:5432/notes?sslmode=disable" \
  quay.io/prometheuscommunity/postgres-exporter:v0.20.1 --web.listen-address=$PRIV:9187 >/dev/null
for i in $(seq 30); do docker exec pg pg_isready -q -U notes && break; sleep 1; done
docker exec pg psql -U notes -tAc 'select version()' | cut -c1-40
