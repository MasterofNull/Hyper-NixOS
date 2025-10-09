#!/usr/bin/env bash
set -euo pipefail
: "${DIALOG:=whiptail}"

require() { for b in $DIALOG virsh jq; do command -v "$b" >/dev/null 2>&1 || { echo "Missing $b" >&2; exit 1; }; done; }
require

choose_domain() {
  mapfile -t vms < <(virsh list --all --name | sed '/^$/d')
  if (( ${#vms[@]} == 0 )); then $DIALOG --msgbox "No VMs found" 8 40; return 1; fi
  local items=(); for i in "${!vms[@]}"; do items+=("${vms[$i]}" " "); done
  $DIALOG --menu "Select VM" 20 70 10 "${items[@]}" 3>&1 1>&2 2>&3
}

create_snapshot() {
  local dom name
  dom=$(choose_domain || true) || return 1
  name=$($DIALOG --inputbox "Snapshot name" 10 60 3>&1 1>&2 2>&3) || return 1
  virsh snapshot-create-as "$dom" "$name" --atomic --disk-only --quiesce || virsh snapshot-create-as "$dom" "$name"
  $DIALOG --msgbox "Snapshot created" 8 30
}

list_snapshots() {
  local dom
  dom=$(choose_domain || true) || return 1
  virsh snapshot-list "$dom" | ${PAGER:-less}
}

revert_snapshot() {
  local dom name
  dom=$(choose_domain || true) || return 1
  name=$($DIALOG --inputbox "Snapshot name to revert" 10 60 3>&1 1>&2 2>&3) || return 1
  virsh snapshot-revert "$dom" "$name"
}

export_backup() {
  local dom out
  dom=$(choose_domain || true) || return 1
  out=$($DIALOG --inputbox "Backup output path (.qcow2)" 10 70 3>&1 1>&2 2>&3) || return 1
  # naive export: find primary disk path and convert
  disk=$(virsh domblklist "$dom" --details | awk '/disk/ {print $4; exit}')
  qemu-img convert -O qcow2 "$disk" "$out"
  $DIALOG --msgbox "Backup exported to $out" 8 60
}

while true; do
  choice=$($DIALOG --menu "Snapshots & Backups" 22 80 12 \
    1 "Create snapshot" \
    2 "List snapshots" \
    3 "Revert to snapshot" \
    4 "Export backup (qcow2)" \
    5 "Exit" 3>&1 1>&2 2>&3) || exit 0
  case "$choice" in
    1) create_snapshot ;;
    2) list_snapshots ;;
    3) revert_snapshot ;;
    4) export_backup ;;
    5) exit 0 ;;
  esac
done
