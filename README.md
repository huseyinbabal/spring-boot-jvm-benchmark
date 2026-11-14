# Spring Boot on five JVMs

The same Spring Boot jar on five Java 25 JVMs, under the same load on the same server, with default settings:
Eclipse Temurin, Amazon Corretto, Azul Zulu, IBM Semeru (OpenJ9) and GraalVM Community (JIT mode).

- Video (English): https://youtu.be/FEQ5NI8Jh0g
- Video (Turkish): https://youtu.be/GGh1cNJR7H4
- Article with all results: https://huseyinbabal.dev/posts/spring-boot-five-jvms-benchmark/

## What's here

| Path | What it is |
|---|---|
| `app/` | Notes API: Spring Boot 4.1.2, Spring Data JPA, Flyway, Hikari pool of 20, Actuator + Prometheus |
| `app/Dockerfile` | One Dockerfile for all five images. The base image is a build argument; the jar is the same file in every image |
| `jvms.txt` | The five base images with exact tags |
| `infra/create.sh` | Creates the three DigitalOcean droplets in lon1: app (c-2), database (c-4), load (c-8) |
| `infra/setup-*.sh` | Machine setup: Docker + cAdvisor + the five images on the app machine, Postgres 17 + postgres_exporter on the database machine, k6 + Prometheus + Grafana on the load machine |
| `infra/run.sh` | The test run, executed on the load machine |
| `infra/load.js` | k6 script: `read`, `write` and `mixed` modes |
| `grafana/` | The two Grafana dashboards used during the runs |
| `results/run2/` | Raw output of the published run: `startup.json`, k6 summaries (`read/write/mixed.json` and `.log`) and the app log per JVM, plus `phases.log` and `metrics.json` (Prometheus averages per test) |
| `results/metrics.py`, `jit.json`, `series.json` | Prometheus queries and time series used for the charts |

## How a run works

For each JVM, `run.sh`:

1. Drops the tables and starts the container (the clock starts here).
2. Polls until the first `200` response and records that time as startup.
3. Seeds 200,000 notes and lets the app sit idle for 60 s.
4. Runs three k6 tests, 10 minutes each with 100 virtual users:
   - `read`: 70% get one note by ID, 30% list by tag
   - `write`: 50% create, 50% update
   - `mixed`: 80% read, 20% write

No JVM flags and no tuning. The results hold for this app on a fully loaded 2 vCPU machine.

## Reproduce

```bash
# DigitalOcean CLI logged in, an SSH key uploaded to your account
SSH_KEY_NAME=<your key name> bash infra/create.sh
(cd app && ./mvnw -q package -DskipTests)    # builds target/notes.jar
# copy app/, jvms.txt, infra/common.sh and the setup script to each machine, then:
#   app machine:   bash setup-app.sh
#   db machine:    PRIV=<db private ip> bash setup-db.sh
#   load machine:  APP=<app private ip> DB=<db private ip> bash setup-load.sh
#   load machine:  APP=<app private ip> DB=<db private ip> DUR=10m bash run.sh
```

Delete the droplets when you're done: `doctl compute droplet delete --tag-name jvmwars`.
