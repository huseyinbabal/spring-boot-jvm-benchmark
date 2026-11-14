#!/usr/bin/env bash
# jw-app (c-2), jw-db (c-4), jw-load (c-8) in lon1, tag jvmwars. Writes IPs only into files, never prints them.
set -euo pipefail; cd "$(dirname "$0")"
KEY=$(doctl compute ssh-key list --format ID,Name --no-header | awk -v k="${SSH_KEY_NAME:?set SSH_KEY_NAME to your DigitalOcean SSH key name}" '$2==k{print $1}')
for spec in jw-app:c-2 jw-db:c-4 jw-load:c-8; do
  doctl compute droplet create ${spec%%:*} --size ${spec##*:} --region lon1 --image ubuntu-24-04-x64 --ssh-keys $KEY --tag-name jvmwars --wait >/dev/null &
done; wait
: > ssh_config
for n in jw-app jw-db jw-load; do
  cat >> ssh_config <<CFG
Host $n
  HostName $(doctl compute droplet get $n --format PublicIPv4 --no-header)
  User root
  IdentityFile ~/.ssh/id_rsa
  IdentitiesOnly yes
  LogLevel ERROR
  StrictHostKeyChecking accept-new
  UserKnownHostsFile $PWD/known_hosts
  ServerAliveInterval 15
CFG
  doctl compute droplet get $n --format PrivateIPv4 --no-header > ${n#jw-}_ip
done
rm -f known_hosts
doctl compute droplet list --tag-name jvmwars --format Name,Size,Region,Status --no-header
