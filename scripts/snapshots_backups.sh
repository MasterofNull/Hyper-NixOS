#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM

: "${DIALOG:=whiptail}"
STATE_DIR="/var/lib/hypervisor"
XML_DIR="$STATE_DIR/xml"

require() { for b in "$@"; do command -v "$b" >/dev/null 2>&1 || { echo "Missing $b" >&2; exit 1; }; done; }
require "$DIALOG" jq virsh

select_domain() {
  local entries=()
  while IFS= read -r name; do entries+=("$name" " "); done < <(virsh list --all --name | sed '/^$/d')
  (( ${#entries[@]} == 0 )) && { $DIALOG --msgbox "No domains found" 8 40; return 1; }
  $DIALOG --menu "Select VM" 22 70 12 "${entries[@]}" 3>&1 1>&2 2>&3
}

list_snapshots() {
  local vm="$1"
  virsh snapshot-list "$vm" --tree || true
}

create_snapshot() {
  local vm="$1" snap
  snap=$($DIALOG --inputbox "Snapshot name" 10 60 3>&1 1>&2 2>&3) || return 1
  virsh snapshot-create-as "$vm" "$snap" --disk-only --atomic --no-metadata || virsh snapshot-create-as "$vm" "$snap"
}

revert_snapshot() {
  local vm="$1" snap
  mapfile -t snaps < <(virsh snapshot-list "$vm" --name | sed '/^$/d')
  (( ${#snaps[@]} == 0 )) && { $DIALOG --msgbox "No snapshots for $vm" 8 40; return 1; }
  items=(); for s in "${snaps[@]}"; do items+=("$s" " "); done
  snap=$($DIALOG --menu "Revert to snapshot" 22 70 12 "${items[@]}" 3>&1 1>&2 2>&3) || return 1
  virsh snapshot-revert "$vm" "$snap"
}

delete_snapshot() {
  local vm="$1" snap
  mapfile -t snaps < <(virsh snapshot-list "$vm" --name | sed '/^$/d')
  (( ${#snaps[@]} == 0 )) && { $DIALOG --msgbox "No snapshots for $vm" 8 40; return 1; }
  items=(); for s in "${snaps[@]}"; do items+=("$s" " "); done
  snap=$($DIALOG --menu "Delete snapshot" 22 70 12 "${items[@]}" 3>&1 1>&2 2>&3) || return 1
  virsh snapshot-delete "$vm" "$snap"
}

backup_vm() {
  local vm="$1" out
  out=$($DIALOG --inputbox "Backup output path (.xml will be created)" 10 70 "$XML_DIR/${vm}-backup.xml" 3>&1 1>&2 2>&3) || return 1
  mkdir -p "$(dirname "$out")"
  virsh dumpxml "$vm" > "$out"
  $DIALOG --msgbox "Saved domain XML to $out\nNote: disk backups are not included in this simple export." 10 70
}

while true; do
  choice=$($DIALOG --menu "Snapshots & Backups" 22 80 14 \
    sel "Select VM" \
    list "List snapshots" \
    create "Create snapshot" \
    revert "Revert to snapshot" \
    delete "Delete snapshot" \
    backup "Export domain XML" \
    exit "Exit" 3>&1 1>&2 2>&3 || true)
  case "$choice" in
    sel) vm=$(select_domain || true) || continue ;;
    list) [[ -z "${vm:-}" ]] && vm=$(select_domain || true) || true; [[ -z "${vm:-}" ]] && continue; list_snapshots "$vm" | ${PAGER:-less} ;;
    create) [[ -z "${vm:-}" ]] && vm=$(select_domain || true) || true; [[ -z "${vm:-}" ]] && continue; create_snapshot "$vm" ;;
    revert) [[ -z "${vm:-}" ]] && vm=$(select_domain || true) || true; [[ -z "${vm:-}" ]] && continue; revert_snapshot "$vm" ;;
    delete) [[ -z "${vm:-}" ]] && vm=$(select_domain || true) || true; [[ -z "${vm:-}" ]] && continue; delete_snapshot "$vm" ;;
    backup) [[ -z "${vm:-}" ]] && vm=$(select_domain || true) || true; [[ -z "${vm:-}" ]] && continue; backup_vm "$vm" ;;
    *) exit 0 ;;
  esac
done
