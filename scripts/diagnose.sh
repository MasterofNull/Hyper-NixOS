#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

: "${DIALOG:=whiptail}"
export DIALOG

echo "═══════════════════════════════════════════════════════"
echo "  Hypervisor Diagnostic Report"
echo "  Generated: $(date)"
echo "═══════════════════════════════════════════════════════"
echo ""

# System info
echo "## System Information"
echo "Hostname: $(hostname)"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo "Uptime: $(uptime -p)"
echo "NixOS Version: $(nixos-version 2>/dev/null || echo "Unknown")"
echo ""

# KVM availability
echo "## Virtualization Support"
if [[ -e /dev/kvm ]]; then
  echo "✓ KVM device present: /dev/kvm"
  if [[ -r /dev/kvm && -w /dev/kvm ]]; then
    echo "✓ KVM device accessible"
  else
    echo "✗ KVM device not accessible (check permissions)"
    echo "  Fix: Add your user to the libvirtd group: sudo usermod -aG libvirtd $USER"
  fi
else
  echo "✗ KVM device missing"
  echo "  Cause: Virtualization may be disabled in BIOS/UEFI"
  echo "  Fix: Enable Intel VT-x or AMD-V in BIOS/UEFI settings"
fi

# Check CPU virtualization features
if grep -q -E '(vmx|svm)' /proc/cpuinfo; then
  if grep -q vmx /proc/cpuinfo; then
    echo "✓ Intel VT-x supported"
  elif grep -q svm /proc/cpuinfo; then
    echo "✓ AMD-V supported"
  fi
else
  echo "✗ No CPU virtualization extensions detected"
fi
echo ""

# IOMMU
echo "## IOMMU Support (for VFIO/GPU passthrough)"
if dmesg | grep -qi "iommu.*enabled" 2>/dev/null; then
  echo "✓ IOMMU enabled"
  if compgen -G "/sys/kernel/iommu_groups/*/devices/*" > /dev/null; then
    group_count=$(find /sys/kernel/iommu_groups/ -maxdepth 1 -mindepth 1 -type d | wc -l)
    echo "✓ IOMMU groups present: $group_count groups"
  fi
else
  echo "✗ IOMMU not enabled"
  echo "  Fix: Add kernel parameters:"
  echo "    Intel: intel_iommu=on iommu=pt"
  echo "    AMD: amd_iommu=on iommu=pt"
fi
echo ""

# Libvirt
echo "## Libvirt Status"
if systemctl is-active --quiet libvirtd; then
  echo "✓ libvirtd is running"
  
  # Check default network
  if virsh net-info default 2>/dev/null | grep -q "Active.*yes"; then
    echo "✓ Default network is active"
  else
    echo "✗ Default network is not active"
    echo "  Fix: virsh net-start default"
  fi
  
  # Check libvirt version
  if command -v virsh >/dev/null 2>&1; then
    virsh_version=$(virsh version | grep "library" | awk '{print $3}')
    echo "  Libvirt version: ${virsh_version:-Unknown}"
  fi
else
  echo "✗ libvirtd is not running"
  echo "  Fix: sudo systemctl start libvirtd"
  echo "       sudo systemctl enable libvirtd"
fi
echo ""

# Storage
echo "## Storage Space"
df -h /var/lib/hypervisor 2>/dev/null || df -h /var/lib | head -2
echo ""

if [[ -d /var/lib/hypervisor ]]; then
  echo "Disk usage by directory:"
  du -sh /var/lib/hypervisor/* 2>/dev/null | head -10 || echo "  No hypervisor directories yet"
else
  echo "✗ Hypervisor directory not found: /var/lib/hypervisor"
  echo "  This will be created when you create your first VM"
fi
echo ""

# Network bridges
echo "## Network Bridges"
if ip link show type bridge 2>/dev/null | grep -q "^[0-9]"; then
  echo "Configured bridges:"
  ip -br link show type bridge | awk '{print "  " $0}'
else
  echo "✗ No bridges configured"
  echo "  Fix: Run bridge helper from menu or create manually"
fi

# Check for common bridge names
for br in br0 virbr0; do
  if ip link show $br >/dev/null 2>&1; then
    echo ""
    echo "Bridge $br:"
    ip -4 addr show $br | grep inet | awk '{print "  IP: " $2}'
    bridge link show $br 2>/dev/null | wc -l | awk '{print "  Ports: " $1}'
  fi
done
echo ""

# VMs
echo "## Virtual Machines"
if [[ -d /var/lib/hypervisor/vm_profiles ]]; then
  vm_count=$(ls -1 /var/lib/hypervisor/vm_profiles/*.json 2>/dev/null | wc -l)
  echo "VM Profiles: $vm_count"
else
  echo "VM Profiles: 0 (directory not found)"
fi

if command -v virsh >/dev/null 2>&1 && systemctl is-active --quiet libvirtd; then
  running_vms=$(virsh list --name 2>/dev/null | grep -v '^$' | wc -l)
  total_vms=$(virsh list --all --name 2>/dev/null | grep -v '^$' | wc -l)
  echo "Defined VMs: $total_vms"
  echo "Running VMs: $running_vms"
  
  if [[ $total_vms -gt 0 ]]; then
    echo ""
    echo "VM Status:"
    virsh list --all 2>/dev/null | tail -n +3 | head -10
  fi
else
  echo "Cannot query VM status (libvirt not available)"
fi
echo ""

# ISOs
echo "## ISO Images"
if [[ -d /var/lib/hypervisor/isos ]]; then
  iso_count=$(ls -1 /var/lib/hypervisor/isos/*.iso 2>/dev/null | wc -l)
  echo "Downloaded ISOs: $iso_count"
  if [[ $iso_count -gt 0 ]]; then
    echo "Recent ISOs:"
    ls -lah /var/lib/hypervisor/isos/*.iso 2>/dev/null | tail -5 | awk '{print "  " $9 " (" $5 ")"}'
  fi
else
  echo "ISO directory not found"
fi
echo ""

# AppArmor
echo "## Security Status"
if command -v aa-status >/dev/null 2>&1; then
  if aa-status >/dev/null 2>&1; then
    echo "✓ AppArmor is active"
    profile_count=$(aa-status --profiled 2>/dev/null || echo "0")
    echo "  Profiles loaded: $profile_count"
    
    # Check for QEMU confinement
    if aa-status 2>/dev/null | grep -q "qemu-system"; then
      echo "✓ QEMU is confined by AppArmor"
    else
      echo "✗ QEMU is not confined by AppArmor"
    fi
  else
    echo "✗ AppArmor not active"
  fi
else
  echo "✗ AppArmor not available"
fi

# Check firewall
if systemctl is-active --quiet firewall 2>/dev/null || systemctl is-active --quiet nftables 2>/dev/null; then
  echo "✓ Firewall is active"
else
  echo "⚠ Firewall status unknown"
fi
echo ""

# Hardware capabilities
echo "## Hardware Capabilities"
# CPU count
cpu_count=$(nproc)
echo "CPU Cores: $cpu_count"

# Memory
total_mem=$(free -h | awk '/^Mem:/ {print $2}')
available_mem=$(free -h | awk '/^Mem:/ {print $7}')
echo "Memory: $available_mem available of $total_mem total"

# Hugepages
if grep -q "HugePages_Total.*[1-9]" /proc/meminfo; then
  hugepages=$(grep "HugePages_Total" /proc/meminfo | awk '{print $2}')
  echo "✓ Hugepages configured: $hugepages pages"
else
  echo "✗ Hugepages not configured"
  echo "  Note: Hugepages can improve VM performance"
fi
echo ""

# Recent errors
echo "## Recent Errors (last 24h)"
error_found=false

if [[ -f /var/lib/hypervisor/logs/menu.log ]]; then
  recent_errors=$(grep -i error /var/lib/hypervisor/logs/menu.log 2>/dev/null | tail -5)
  if [[ -n "$recent_errors" ]]; then
    echo "Menu errors:"
    echo "$recent_errors" | sed 's/^/  /'
    error_found=true
  fi
fi

if journalctl -u libvirtd --since "24 hours ago" >/dev/null 2>&1; then
  libvirt_errors=$(journalctl -u libvirtd --since "24 hours ago" -p err --no-pager 2>/dev/null | tail -5)
  if [[ -n "$libvirt_errors" ]]; then
    [[ "$error_found" == true ]] && echo ""
    echo "Libvirt errors:"
    echo "$libvirt_errors" | sed 's/^/  /'
    error_found=true
  fi
fi

if [[ "$error_found" == false ]]; then
  echo "  No recent errors found"
fi
echo ""

# Common issues check
echo "## Quick Health Check"
issues=0

# Check if user is in libvirtd group
if ! groups | grep -q libvirtd; then
  echo "⚠ User not in libvirtd group"
  echo "  Fix: sudo usermod -aG libvirtd $USER && newgrp libvirtd"
  ((issues++))
fi

# Check disk space
available_space=$(df /var/lib/hypervisor 2>/dev/null | tail -1 | awk '{print $4}' || df /var/lib | tail -1 | awk '{print $4}')
if [[ $available_space -lt 10485760 ]]; then  # Less than 10GB
  echo "⚠ Low disk space (less than 10GB available)"
  echo "  Fix: Free up space or add more storage"
  ((issues++))
fi

# Check if SELinux is enforcing (can cause issues)
if command -v getenforce >/dev/null 2>&1 && [[ "$(getenforce)" == "Enforcing" ]]; then
  echo "⚠ SELinux is enforcing (may cause issues with NixOS)"
  echo "  Note: NixOS typically uses AppArmor instead"
  ((issues++))
fi

if [[ $issues -eq 0 ]]; then
  echo "✓ No immediate issues detected"
fi
echo ""

echo "═══════════════════════════════════════════════════════"
echo "Diagnostic report complete"
echo ""
echo "For detailed logs, check:"
echo "  - Menu logs: /var/lib/hypervisor/logs/menu.log"
echo "  - Libvirt logs: journalctl -u libvirtd -f"
echo "  - System logs: journalctl -f"
echo ""
echo "For help, consult:"
echo "  - Quick start: /etc/hypervisor/docs/quickstart.txt"
echo "  - Documentation: /etc/hypervisor/docs/"
echo "═══════════════════════════════════════════════════════"