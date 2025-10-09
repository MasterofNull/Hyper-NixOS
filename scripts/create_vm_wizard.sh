#!/usr/bin/env bash
set -euo pipefail

PROFILES_DIR="${1:-/var/lib/hypervisor/vm_profiles}"
ISOS_DIR="${2:-/var/lib/hypervisor/isos}"
: "${DIALOG:=whiptail}"

require() { for b in jq $DIALOG; do command -v "$b" >/dev/null 2>&1 || { echo "Missing $b" >&2; exit 1; }; done; }
require

ask() { $DIALOG --inputbox "$1" 10 60 "$2" 3>&1 1>&2 2>&3; }

name=$(ask "VM name" "my-vm") || exit 0
cpus=$(ask "vCPUs" "2") || exit 0
mem=$(ask "Memory (MiB)" "4096") || exit 0
disk=$(ask "Disk size (GiB)" "20") || exit 0

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
  "network": { "bridge": "" }
}
JSON

$DIALOG --msgbox "Created profile: $profile_json" 8 60
