#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM
IFS=$'\n\t'
umask 077

PROFILES_DIR="${1:-/var/lib/hypervisor/vm_profiles}"
ISOS_DIR="${2:-/var/lib/hypervisor/isos}"
: "${DIALOG:=whiptail}"
export DIALOG

require() { for b in jq $DIALOG; do command -v "$b" >/dev/null 2>&1 || { echo "Missing $b" >&2; exit 1; }; done; }
require

ask() { $DIALOG --inputbox "$1" 10 60 "$2" 3>&1 1>&2 2>&3; }

# Detect available system resources
total_mem_kb=$(awk '/MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
avail_mem_kb=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
total_mem_mb=$(( total_mem_kb / 1024 ))
avail_mem_mb=$(( avail_mem_kb / 1024 ))
total_cpus=$(nproc 2>/dev/null || echo 1)

$DIALOG --msgbox "Host resources detected:\n\nCPUs: ${total_cpus}\nTotal RAM: ${total_mem_mb} MiB\nAvailable RAM: ${avail_mem_mb} MiB" 12 60

name=$(ask "VM name" "my-vm") || exit 0
cpus=$(ask "vCPUs (host: ${total_cpus})" "2") || exit 0
mem=$(ask "Memory (MiB) (avail: ${avail_mem_mb}, total: ${total_mem_mb})" "4096") || exit 0
disk=$(ask "Disk size (GiB)" "20") || exit 0

# Optional: variable memory limits (ballooning) via memory_max_mb and soft limit
if $DIALOG --yesno "Enable variable memory limit (soft cap)?\n\nThis sets a memory_max_mb higher than the initial memory, allowing flexibility." 12 70 ; then
  mem_max=$(ask "Max memory (MiB) (>= ${mem})" "$(( mem + 1024 ))") || exit 0
else
  mem_max=${mem}
fi

# ISO selection
shopt -s nullglob
isos=( "$ISOS_DIR"/*.iso )
shopt -u nullglob
if (( ${#isos[@]} == 0 )); then
  $DIALOG --msgbox "No ISOs found in $ISOS_DIR. Use ISO manager first." 10 70
  exit 0
fi

iso_choices=()
for f in "${isos[@]}"; do iso_choices+=("$f" " "); done
iso_path=$($DIALOG --menu "Select ISO" 20 70 10 "${iso_choices[@]}" 3>&1 1>&2 2>&3) || exit 0

profile_json="$PROFILES_DIR/${name}.json"
mkdir -p "$PROFILES_DIR"
cat > "$profile_json" <<JSON
{
  "name": "${name}",
  "os": "generic",
  "cpus": ${cpus},
  "memory_mb": ${mem},
  "disk_gb": ${disk},
  "iso_path": "${iso_path}",
  "network": { "bridge": "" },
  "limits": { "cpu_quota_percent": 200, "memory_max_mb": ${mem_max} }
}
JSON

$DIALOG --msgbox "Created profile: $profile_json" 8 60
