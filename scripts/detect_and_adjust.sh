#!/usr/bin/env bash
# Detect common host devices and adjust AppArmor and firewall guidance
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM
: "${DIALOG:=whiptail}"
export DIALOG

has() { command -v "$1" >/dev/null 2>&1; }

report=""

# Cameras
if ls /dev/video* >/dev/null 2>&1; then
  report+=$'[✓] Camera devices detected (/dev/video*) allowed by AppArmor\n'
fi
# Audio
if ls /dev/snd/* >/dev/null 2>&1; then
  report+=$'[✓] Sound devices detected (/dev/snd/**) allowed by AppArmor\n'
fi
# USB
if ls /dev/bus/usb/* >/dev/null 2>&1; then
  report+=$'[✓] USB bus devices allowed (/dev/bus/usb/**)\n'
fi
# Input
if ls /dev/input/* >/dev/null 2>&1; then
  report+=$'[✓] Input devices (/dev/input/**, /dev/hidraw*, /dev/uinput) allowed\n'
fi
# VFIO
if ls /dev/vfio/* >/dev/null 2>&1; then
  report+=$'[✓] VFIO groups present; AppArmor allows /dev/vfio/**\n'
fi
# Network
if lsmod | grep -q vhost_net; then
  report+=$'[✓] vhost_net loaded; allowed by AppArmor (/dev/vhost-net)\n'
fi
# TPM
if ls /dev/tpm* >/dev/null 2>&1; then
  report+=$'[✓] TPM devices present; allowed by AppArmor (/dev/tpm*)\n'
fi

$DIALOG --msgbox "$report\nIf a device is not working, we can relax AppArmor selectively." 22 80
