#!/usr/bin/env bash
# App machine: docker, node_exporter (+ textfile marker), cAdvisor, five notes images. Needs /root/app/{Dockerfile,target/notes.jar} and /root/jvms.txt
set -euo pipefail; source /root/common.sh
mkdir -p /var/lib/prometheus/node-exporter
docker rm -f cadvisor >/dev/null 2>&1 || true
docker run -d --name cadvisor --restart=always --network host --privileged \
  -v /:/rootfs:ro -v /var/run:/var/run:ro -v /sys:/sys:ro -v /var/lib/docker/:/var/lib/docker:ro -v /dev/disk/:/dev/disk:ro \
  ghcr.io/google/cadvisor:v0.60.6 --port=8088 --docker_only=true --housekeeping_interval=1s \
  --disable_metrics=advtcp,cpu_topology,cpuset,hugetlb,memory_numa,percpu,process,referenced_memory,resctrl,sched,tcp,udp,disk,diskIO >/dev/null
cd /root/app
while read n img; do docker build -q --build-arg BASE=$img --build-arg JVM=$n -t notes-$n . >/dev/null; echo "built notes-$n"; done < /root/jvms.txt
docker images --format '{{.Repository}} {{.Size}}' | grep '^notes-'
