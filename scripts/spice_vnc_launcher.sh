#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM

: "${DIALOG:=whiptail}"

require() { for b in "$@"; do command -v "$b" >/dev/null 2>&1 || { echo "Missing $b" >&2; exit 1; }; done; }
require "$DIALOG" virsh awk

select_vm() { virsh list --all --name | sed '/^$/d' | awk '{print NR-1, $1}'; }

vm=$($DIALOG --menu "Select VM" 22 70 14 $(select_vm) 3>&1 1>&2 2>&3 || exit 0)

proto=$(virsh domdisplay "$vm" 2>/dev/null | awk -F: '{print $1}')
url=$(virsh domdisplay "$vm" 2>/dev/null)
if [[ "$proto" == spice || "$proto" == vnc ]]; then
  $DIALOG --msgbox "Display: $url\nUse a $proto client to connect." 10 70
else
  $DIALOG --msgbox "No remote display found (SPICE/VNC)." 8 50
fi
