#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM

: "${DIALOG:=whiptail}"

require() { for b in "$@"; do command -v "$b" >/dev/null 2>&1 || { echo "Missing $b" >&2; exit 1; }; done; }
require "$DIALOG" virsh

select_vm() { virsh list --name | sed '/^$/d' | awk '{print NR-1, $1}'; }

vm=$($DIALOG --menu "Select VM (QGA required)" 22 70 14 $(select_vm) 3>&1 1>&2 2>&3 || exit 0)

choice=$($DIALOG --menu "Guest agent action on $vm" 16 70 8 \
  shutdown "ACPI shutdown via QGA" \
  fsfreeze "Freeze filesystems" \
  fsthaw "Thaw filesystems" \
  exit "Exit" 3>&1 1>&2 2>&3 || exit 0)

case "$choice" in
  shutdown) virsh qemu-agent-command "$vm" '{"execute":"guest-shutdown"}' || true ;;
  fsfreeze) virsh qemu-agent-command "$vm" '{"execute":"guest-fsfreeze-freeze"}' || true ;;
  fsthaw)   virsh qemu-agent-command "$vm" '{"execute":"guest-fsfreeze-thaw"}' || true ;;
  *) : ;;
 esac
