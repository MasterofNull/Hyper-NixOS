#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
: "${DIALOG:=whiptail}"
export DIALOG

check() { printf "[ ] %s\n" "$1"; }
ok()    { printf "[✓] %s\n" "$1"; }
warn()  { printf "[!] %s\n" "$1"; }

run_checks() {
  out=""
  # KVM
  if [[ -e /dev/kvm ]]; then out+="$(ok 'KVM device present')\n"; else out+="$(warn 'KVM device missing (/dev/kvm)')\n"; fi
  # IOMMU
  if dmesg | grep -qi iommu; then out+="$(ok 'IOMMU enabled')\n"; else out+="$(warn 'IOMMU not enabled')\n"; fi
  # ACS
  if dmesg | grep -qi 'pci.*acs'; then out+="$(ok 'PCIe ACS present')\n"; else out+="$(warn 'PCIe ACS may be missing')\n"; fi
  # AppArmor
  if aa-status >/dev/null 2>&1; then out+="$(ok 'AppArmor loaded')\n"; else out+="$(warn 'AppArmor not active')\n"; fi
  # libvirtd
  if systemctl is-active --quiet libvirtd; then out+="$(ok 'libvirtd active')\n"; else out+="$(warn 'libvirtd not active')\n"; fi
  # Bridges
  if ip link show type bridge >/dev/null 2>&1; then out+="$(ok 'Bridge support present')\n"; else out+="$(warn 'No bridges found')\n"; fi
  # Hugepages
  if [[ -f /proc/meminfo ]] && grep -q 'HugePages_Total' /proc/meminfo; then out+="$(ok 'Hugepages supported')\n"; fi
  printf "%b" "$out"
}

$DIALOG --title "Preflight Check" --msgbox "$(run_checks)\n\nReview warnings if any." 20 80
