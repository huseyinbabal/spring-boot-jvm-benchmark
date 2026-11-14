# shared by the three setup scripts: firewall (ssh + private network only) and node_exporter
export DEBIAN_FRONTEND=noninteractive
cloud-init status --wait >/dev/null 2>&1 || true
apt-get update -qq; apt-get install -y -qq ufw prometheus-node-exporter docker.io >/dev/null 2>&1
ufw --force reset >/dev/null; ufw default deny incoming >/dev/null; ufw default allow outgoing >/dev/null
ufw allow 22/tcp >/dev/null; ufw allow from 10.0.0.0/8 >/dev/null; ufw --force enable >/dev/null
systemctl enable -q --now prometheus-node-exporter docker
