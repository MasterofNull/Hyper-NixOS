#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM

: "${DIALOG:=whiptail}"
STATE_DIR="/var/lib/hypervisor"
DISKS_DIR="$STATE_DIR/disks"
PROFILES_DIR="$STATE_DIR/vm_profiles"

require() { for b in "$@"; do command -v "$b" >/dev/null 2>&1 || { echo "Missing $b" >&2; exit 1; }; done; }
require "$DIALOG" jq qemu-img

select_profile() { shopt -s nullglob; for f in "$PROFILES_DIR"/*.json; do name=$(jq -r .name "$f" 2>/dev/null || basename "$f"); echo "$f" "$name"; done; shopt -u nullglob; }

choice=$($DIALOG --menu "Template/Clone Manager" 22 90 12 \
  make_template "Mark VM disk as template (read-only)" \
  clone "Create linked clone from template" \
  fullclone "Create full clone (independent copy)" \
  exit "Exit" 3>&1 1>&2 2>&3 || exit 0)

case "$choice" in
  make_template)
    p=$($DIALOG --menu "Select VM profile" 22 80 14 $(select_profile) 3>&1 1>&2 2>&3 || exit 0)
    name=$(jq -r .name "$p")
    base="$DISKS_DIR/${name}.qcow2"
    [[ -f "$base" ]] || { $DIALOG --msgbox "Missing disk: $base" 8 50; exit 1; }
    chmod a-w "$base" && $DIALOG --msgbox "Marked template (read-only): $base" 8 60 ;;
  clone)
    p=$($DIALOG --menu "Select template profile" 22 80 14 $(select_profile) 3>&1 1>&2 2>&3 || exit 0)
    name=$(jq -r .name "$p")
    base="$DISKS_DIR/${name}.qcow2"
    [[ -f "$base" ]] || { $DIALOG --msgbox "Missing disk: $base" 8 50; exit 1; }
    newname=$($DIALOG --inputbox "New VM name" 10 60 3>&1 1>&2 2>&3) || exit 0
    qemu-img create -f qcow2 -b "$base" "$DISKS_DIR/${newname}.qcow2" && $DIALOG --msgbox "Linked clone created: ${newname}" 8 60 ;;
  fullclone)
    p=$($DIALOG --menu "Select source profile" 22 80 14 $(select_profile) 3>&1 1>&2 2>&3 || exit 0)
    name=$(jq -r .name "$p")
    base="$DISKS_DIR/${name}.qcow2"
    [[ -f "$base" ]] || { $DIALOG --msgbox "Missing disk: $base" 8 50; exit 1; }
    newname=$($DIALOG --inputbox "New VM name" 10 60 3>&1 1>&2 2>&3) || exit 0
    qemu-img convert -O qcow2 "$base" "$DISKS_DIR/${newname}.qcow2" && $DIALOG --msgbox "Full clone created: ${newname}" 8 60 ;;
  *) : ;;
esac
