#!/usr/bin/env bash
# Load machine: k6, Prometheus (1 s scrape, k6 remote write), Grafana on localhost.  APP=<ip> DB=<ip> bash setup-load.sh
set -euo pipefail; source /root/common.sh
apt-get install -y -qq gnupg curl jq prometheus postgresql-client tmux >/dev/null 2>&1
curl -fsSL https://dl.k6.io/key.gpg | gpg --dearmor --yes -o /usr/share/keyrings/k6.gpg
echo "deb [signed-by=/usr/share/keyrings/k6.gpg] https://dl.k6.io/deb stable main" > /etc/apt/sources.list.d/k6.list
mkdir -p /etc/apt/keyrings; curl -fsSL https://apt.grafana.com/gpg.key | gpg --dearmor --yes -o /etc/apt/keyrings/grafana.gpg
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" > /etc/apt/sources.list.d/grafana.list
apt-get update -qq; apt-get install -y -qq k6 grafana >/dev/null 2>&1
cat > /etc/prometheus/prometheus.yml <<YML
global: {scrape_interval: 1s, scrape_timeout: 900ms}
scrape_configs:
  - {job_name: app-node, static_configs: [{targets: ["$APP:9100"]}]}
  - {job_name: actuator, scrape_interval: 5s, scrape_timeout: 4s, metrics_path: /actuator/prometheus, static_configs: [{targets: ["$APP:9091"]}]}
  - {job_name: cadvisor, static_configs: [{targets: ["$APP:8088"]}], metric_relabel_configs: [{source_labels: [name], regex: "notes-.*", action: keep}]}
  - {job_name: db-node, static_configs: [{targets: ["$DB:9100"]}]}
  - {job_name: postgres, static_configs: [{targets: ["$DB:9187"]}]}
YML
sed -i "s|^ARGS=.*|ARGS=\"--web.listen-address=127.0.0.1:9090 --web.enable-remote-write-receiver --enable-feature=native-histograms --web.enable-admin-api --storage.tsdb.retention.time=30d\"|" /etc/default/prometheus
sed -i 's|^;http_addr =.*|http_addr = 127.0.0.1|' /etc/grafana/grafana.ini
grep -q '^min_refresh_interval' /etc/grafana/grafana.ini || sed -i '0,/^\[dashboards\]/s//[dashboards]\nmin_refresh_interval = 1s/' /etc/grafana/grafana.ini
grep -q '^\[auth.anonymous\]' /etc/grafana/grafana.ini || printf '[auth.anonymous]\nenabled = true\norg_role = Viewer\n' >> /etc/grafana/grafana.ini
mkdir -p /etc/grafana/provisioning/datasources /etc/grafana/provisioning/dashboards /var/lib/grafana/dashboards
echo 'apiVersion: 1
datasources: [{name: prom, uid: prom, type: prometheus, url: "http://127.0.0.1:9090", isDefault: true, jsonData: {timeInterval: 1s}}]' > /etc/grafana/provisioning/datasources/prom.yaml
echo 'apiVersion: 1
providers: [{name: files, type: file, updateIntervalSeconds: 5, options: {path: /var/lib/grafana/dashboards}}]' > /etc/grafana/provisioning/dashboards/files.yaml
cp /root/dash/*.json /var/lib/grafana/dashboards/
sysctl -qw net.ipv4.ip_local_port_range="1024 65000" net.ipv4.tcp_tw_reuse=1
grep -q GF_AUTH_ANONYMOUS_ENABLED /etc/default/grafana-server || printf "GF_AUTH_ANONYMOUS_ENABLED=true
GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer
GF_DASHBOARDS_MIN_REFRESH_INTERVAL=1s
" >> /etc/default/grafana-server; systemctl restart grafana-server
systemctl restart prometheus
k6 version | head -1; prometheus --version 2>&1 | head -1
