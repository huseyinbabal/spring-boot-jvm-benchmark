#!/usr/bin/env bash
# Runs on jw-load. For each JVM: fresh database, start, startup time, 200k rows, 60 s idle, then read / write / mixed for DUR each.
# APP=<ip> DB=<ip> DUR=10m bash run.sh   ->  /root/results/<jvm>/...
set -uo pipefail
DUR=${DUR:-10m}; N=200000; R=/root/results; mkdir -p $R
SA="ssh -i /root/.ssh/jw -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR root@$APP"
SD="ssh -i /root/.ssh/jw -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR root@$DB"
K6ENV="K6_PROMETHEUS_RW_SERVER_URL=http://127.0.0.1:9090/api/v1/write K6_PROMETHEUS_RW_TREND_AS_NATIVE_HISTOGRAM=true K6_PROMETHEUS_RW_PUSH_INTERVAL=1s"
PSQL="psql postgresql://notes:notes@$DB:5432/notes -qtAX"
mark() { $SA "printf 'jw_phase{jvm=\"$1\",phase=\"$2\"} 1\n' > /var/lib/prometheus/node-exporter/jw.prom.tmp && mv /var/lib/prometheus/node-exporter/jw.prom.tmp /var/lib/prometheus/node-exporter/jw.prom"
         echo "$1 $2 $(date -u +%FT%TZ)" | tee -a $R/phases.log > $R/state; }
for jvm in ${JVMS:-temurin corretto semeru zulu graalvm}; do
  mkdir -p $R/$jvm; mark none gap
  $SA "docker rm -f \$(docker ps -aq --filter name=notes-) >/dev/null 2>&1; sync; echo 3 > /proc/sys/vm/drop_caches"
  $PSQL -c 'drop table if exists notes, flyway_schema_history' 2>&1 | grep -v NOTICE
  $SD "docker exec pg psql -U notes -qc checkpoint"; sleep 20
  mark $jvm start; t0=$(date +%s%N)
  $SA "docker run -d --name notes-$jvm --network host -e DB_URL=jdbc:postgresql://$DB:5432/notes notes-$jvm >/dev/null"
  until curl -sf -o /dev/null "http://$APP:8080/notes?tag=java"; do sleep 0.05; done
  t1=$(date +%s%N)
  started=$($SA "docker logs notes-$jvm 2>&1" | grep -o 'Started NotesApplication in [0-9.]* seconds' | grep -o '[0-9.]*' | head -1)
  jq -n --arg jvm $jvm --argjson first_ok_ms $(( (t1 - t0) / 1000000 )) --arg started "$started" \
     --arg version "$($SA "docker exec notes-$jvm java -version 2>&1" | sed -n 2p)" --arg image "$($SA "docker images notes-$jvm --format '{{.Size}}'")" \
     '{jvm:$jvm, first_ok_ms:$first_ok_ms, spring_started_s:($started|tonumber? // null), version:$version, image:$image}' > $R/$jvm/startup.json
  cat $R/$jvm/startup.json | jq -c .
  $PSQL -c "insert into notes (title, body, tag, created_at)
            select 'Note ' || g || ' about ' || (array['java','spring','postgres','k6','grafana','docker','linux','jvm'])[1 + g % 8],
                   repeat('Seeded note body for the JVM test. ', 4), (array['java','spring','postgres','k6','grafana','docker','linux','jvm'])[1 + g % 8], now()
            from generate_series(1, $N) g" && $PSQL -c "vacuum analyze notes"
  mark $jvm idle; sleep 60
  for mode in read write mixed; do
    mark $jvm $mode
    env $K6ENV TARGET=http://$APP:8080 MODE=$mode JVM=$jvm N=$N DUR=$DUR k6 run --quiet -o experimental-prometheus-rw \
        --summary-export $R/$jvm/$mode.json /root/load.js > $R/$jvm/$mode.log 2>&1
    echo "$jvm $mode $(jq -c '{rps: .metrics.http_reqs.rate|floor, p95: .metrics.http_req_duration["p(95)"], p99: .metrics.http_req_duration["p(99)"], failed: .metrics.http_req_failed.value}' $R/$jvm/$mode.json)"
    mark $jvm cool; sleep 15
  done
  $SA "docker logs notes-$jvm" > $R/$jvm/app.log 2>&1
  $SA "docker rm -f notes-$jvm >/dev/null"
done
mark none done
