#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
set -euo pipefail

OUT_JSON="${1:-}"

require() { for b in lspci awk sed jq; do command -v "$b" >/dev/null 2>&1 || { echo "Missing $b" >&2; exit 1; }; done; }
require

# Detect GPU and audio function pairs (common for NVIDIA/AMD)
mapfile -t gpus < <(lspci -Dn | awk '/VGA compatible controller|3D controller/ {print $1" "$3}' )
mapfile -t auds < <(lspci -Dn | awk '/Audio device/ {print $1" "$3}' )

suggest_ids=()
for line in "${gpus[@]}"; do
  dev=$(awk '{print $1}' <<<"$line")
  id=$(awk '{print $2}' <<<"$line")
  suggest_ids+=("$id")
  # find matching audio (same vendor, usually device id differs)
  vend=${id%%:*}
  for a in "${auds[@]}"; do
    aid=$(awk '{print $2}' <<<"$a")
    [[ ${aid%%:*} == "$vend" ]] && suggest_ids+=("$aid")
  done
  break
done

# CPU pin suggestion: reserve 2 cores for host if possible
cpu_count=$(lscpu | awk '/CPU\(s\):/ {print $2; exit}')
reserve=$(( cpu_count>4 ? 2 : 1 ))
pinning=()
for ((i=reserve;i<cpu_count;i++)); do pinning+=("$i"); done

json=$(jq -n --argjson ids "$(printf '%s
' "${suggest_ids[@]}" | jq -R . | jq -s .)" \
            --argjson pin "$(printf '%s
' "${pinning[@]}" | jq -R . | jq -s .)" '{vfio_ids:$ids, cpu_pinning:$pin}')

if [[ -n "${OUT_JSON}" ]]; then
  echo "$json" > "$OUT_JSON"
else
  echo "$json"
fi
