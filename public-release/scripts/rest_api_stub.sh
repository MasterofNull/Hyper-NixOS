#!/usr/bin/env bash
# Minimal REST-like stub using nc; not production-ready
set -Eeuo pipefail
IFS=$'\n\t'
PORT=${1:-8080}
ROOT=/etc/hypervisor

handler() {
  while IFS= read -r line; do [[ "$line" == $'\r' ]] && break; done
  resp=$(mktemp)
  echo "HTTP/1.1 200 OK" > "$resp"
  echo "Content-Type: application/json" >> "$resp"
  echo >> "$resp"
  echo '{"status":"ok","features":["metrics","vms","profiles"]}' >> "$resp"
  cat "$resp"
  rm -f "$resp"
}

while true; do
  nc -l -p "$PORT" -c handler || nc -lk "$PORT" -e handler || sleep 1
done
