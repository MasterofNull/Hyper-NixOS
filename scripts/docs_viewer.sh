#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM

DOCS_DIR="/etc/hypervisor/docs"
: "${PAGER:=less}"
: "${DIALOG:=whiptail}"

show_file() { local f="$1"; [[ -f "$f" ]] && $PAGER "$f" || $DIALOG --msgbox "Missing: $f" 8 40; }

while true; do
  choice=$($DIALOG --menu "Docs & Help" 22 80 14 \
    quickstart "Quickstart - from ISO/image to VM" \
    workflows "Workflows - ISO manager, wizard, deploy" \
    cloudinit "Cloud-init - images and seeds" \
    networking "Networking - zones, bridges, VFIO" \
    storage "Storage - disks, snapshots, backups" \
    firewall "Per-VM firewall" \
    logs "Logs & troubleshooting" \
    exit "Exit" 3>&1 1>&2 2>&3 || true)
  case "$choice" in
    quickstart) show_file "$DOCS_DIR/quickstart.txt" ;;
    workflows) show_file "$DOCS_DIR/workflows.txt" ;;
    cloudinit) show_file "$DOCS_DIR/cloudinit.txt" ;;
    networking) show_file "$DOCS_DIR/networking.txt" ;;
    storage) show_file "$DOCS_DIR/storage.txt" ;;
    firewall) show_file "$DOCS_DIR/firewall.txt" ;;
    logs) show_file "$DOCS_DIR/logs.txt" ;;
    *) exit 0 ;;
  esac
done
