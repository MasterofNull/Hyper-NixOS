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
# CET / AMD / guest_memfd summaries
if grep -qE ' shstk | cet_ss ' /proc/cpuinfo 2>/dev/null; then
  report+=$'[✓] CET Shadow Stack supported by CPU\n'
fi
if grep -qE ' ibt | cet_ib ' /proc/cpuinfo 2>/dev/null; then
  report+=$'[✓] CET IBT supported by CPU\n'
fi
if grep -qi amd /proc/cpuinfo; then
  if dmesg | grep -qi 'x2avic'; then report+=$'[✓] AMD x2AVIC available\n'; fi
  if dmesg | grep -qi 'Secure AVIC'; then report+=$'[✓] AMD Secure AVIC available\n'; fi
  if [[ -d /sys/firmware/sev ]]; then report+=$'[✓] SEV platform present\n'; fi
  if [[ -f /sys/firmware/sev/snp ]]; then report+=$'[✓] SEV-SNP present\n'; fi
fi
if [[ -f /sys/module/kvm/parameters/guest_memfd ]]; then
  report+=$'[✓] guest_memfd parameter detected\n'
fi
# TPM
if ls /dev/tpm* >/dev/null 2>&1; then
  report+=$'[✓] TPM devices present; allowed by AppArmor (/dev/tpm*)\n'
fi

$DIALOG --msgbox "$report\nIf a device is not working, we can relax AppArmor selectively." 22 80
