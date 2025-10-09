#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM
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
  # x86 CET (Shadow Stack / IBT)
  if grep -qE ' shstk | cet_ss ' /proc/cpuinfo 2>/dev/null; then out+="$(ok 'CPU supports CET Shadow Stack')\n"; fi
  if grep -qE ' ibt | cet_ib ' /proc/cpuinfo 2>/dev/null; then out+="$(ok 'CPU supports CET IBT')\n"; fi
  # AMD AVIC/x2AVIC
  if grep -qi amd /proc/cpuinfo && lsmod | grep -q kvm_amd; then
    if dmesg | grep -qi 'x2avic'; then out+="$(ok 'AMD x2AVIC present (Zen4+)')\n"; fi
    if dmesg | grep -qi 'Secure AVIC'; then out+="$(ok 'AMD Secure AVIC supported')\n"; fi
  fi
  # AMD SEV/SEV-ES/SEV-SNP
  if [[ -e /sys/module/kvm_amd/parameters/sev ]]; then out+="$(ok 'Kernel has SEV parameter')\n"; fi
  if [[ -d /sys/firmware/sev ]]; then out+="$(ok 'SEV platform firmware present')\n"; fi
  if [[ -f /sys/firmware/sev/snp ]]; then out+="$(ok 'SEV-SNP present')\n"; fi
  # guest_memfd / private memory
  if [[ -f /sys/module/kvm/parameters/guest_memfd ]]; then out+="$(ok 'guest_memfd parameter present')\n"; fi
  printf "%b" "$out"
}

$DIALOG --title "Preflight Check" --msgbox "$(run_checks)\n\nReview warnings if any." 20 80
