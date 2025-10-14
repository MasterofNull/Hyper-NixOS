#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
set -Eeuo pipefail
IFS=$'\n\t'
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

OUT="${1:-}"  # optional output file

metric() { printf "%s{%s} %s\n" "$1" "$2" "$3"; }
plain() { printf "%s %s\n" "$1" "$2"; }

# Host metrics
uptime_s=$(awk '{print int($1)}' /proc/uptime)
mem_total_kb=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
mem_free_kb=$(awk '/MemFree:/ {print $2}' /proc/meminfo)

# VM metrics
vms=$(virsh list --name 2>/dev/null | sed '/^$/d' || true)
num_vms=$(printf "%s\n" "$vms" | sed '/^$/d' | wc -l | tr -d ' ')

buf=$(mktemp)
metric "hypervisor_uptime_seconds" "" "$uptime_s" >> "$buf"
metric "hypervisor_memory_kilobytes" "type=\"total\"" "$mem_total_kb" >> "$buf"
metric "hypervisor_memory_kilobytes" "type=\"free\"" "$mem_free_kb" >> "$buf"
metric "hypervisor_vms_running" "" "$num_vms" >> "$buf"

while IFS= read -r vm; do
  [[ -z "$vm" ]] && continue
  # dominfo key metrics
  cpu_time_ns=$(virsh dominfo "$vm" 2>/dev/null | awk -F: '/CPU time/ {gsub(/\s+/,"",$2); gsub(/s/,"",$2); printf("%0.0f", $2*1e9)}')
  mem_used_kb=$(virsh dommemstat "$vm" 2>/dev/null | awk '/unused/ {u=$2} /actual/ {a=$2} END{if(a){print a-(u?u:0)} }')
  metric "vm_cpu_time_nanoseconds_total" "vm=\"$vm\"" "${cpu_time_ns:-0}" >> "$buf"
  metric "vm_memory_kilobytes" "vm=\"$vm\",type=\"used\"" "${mem_used_kb:-0}" >> "$buf"
  bridge=$(virsh dumpxml "$vm" 2>/dev/null | awk -F"'" '/<source bridge=/{print $2; exit}')
  [[ -n "$bridge" ]] && metric "vm_network_bridge_info" "vm=\"$vm\",bridge=\"$bridge\"" 1 >> "$buf"
 done <<< "$vms"

if [[ -n "$OUT" ]]; then
  mv "$buf" "$OUT"
else
  cat "$buf"
  rm -f "$buf"
fi
