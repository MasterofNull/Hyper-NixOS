#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM
: "${DIALOG:=whiptail}"

require() { for b in $DIALOG ip jq; do command -v "$b" >/dev/null 2>&1 || { echo "Missing $b" >&2; exit 1; }; done; }
require

msg() { $DIALOG --msgbox "$1" 12 70; }

# Simple helper that displays current links and suggests a bridge name
links=$(ip -o link show | awk -F': ' '{print $2}' | paste -sd ' ' -)
bridge=${1:-br0}

$DIALOG --yesno "Create a bridge $bridge and enslave an interface?\n\nInterfaces: $links" 15 70 || exit 0
iface=$($DIALOG --inputbox "Interface to enslave (e.g., eth0)" 10 60 3>&1 1>&2 2>&3) || exit 0

sudo sh -c "cat >/etc/systemd/network/$bridge.netdev" <<CONF
[NetDev]
Name=$bridge
Kind=bridge
CONF

sudo sh -c "cat >/etc/systemd/network/$bridge.network" <<CONF
[Match]
Name=$bridge

[Network]
DHCP=yes
CONF

sudo sh -c "cat >/etc/systemd/network/$iface.network" <<CONF
[Match]
Name=$iface

[Network]
Bridge=$bridge
CONF

msg "Created netdev/network files. Reboot or restart systemd-networkd to apply."
