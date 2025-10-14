#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

: "${DIALOG:=whiptail}"
export DIALOG

echo "═══════════════════════════════════════════════════════"
echo "  Hypervisor Diagnostic Report"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# System info
echo "## System Information"
echo "Hostname: $(hostname)"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo "Uptime: $(uptime -p)"
echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
echo ""

# KVM availability
echo "## Virtualization Support"
if [[ -e /dev/kvm ]]; then
  echo "✓ KVM device present: /dev/kvm"
  if [[ -r /dev/kvm && -w /dev/kvm ]]; then
    echo "✓ KVM device accessible"
  else
    echo "✗ KVM device not accessible (check permissions)"
    echo "  Current permissions: $(ls -l /dev/kvm)"
    echo "  Fix: Add user to 'kvm' group: sudo usermod -a -G kvm \$USER"
  fi
else
  echo "✗ KVM device missing"
  echo "  Cause: Virtualization may be disabled in BIOS"
  echo "  Fix: Enable Intel VT-x or AMD-V in BIOS/UEFI settings"
fi

# Check CPU virtualization flags
echo ""
echo "CPU Virtualization flags:"
if grep -qE '(vmx|svm)' /proc/cpuinfo 2>/dev/null; then
  if grep -q vmx /proc/cpuinfo; then
    echo "  ✓ Intel VT-x detected"
  fi
  if grep -q svm /proc/cpuinfo; then
    echo "  ✓ AMD-V detected"
  fi
else
  echo "  ✗ No virtualization flags found (vmx/svm missing)"
  echo "  Fix: Enable virtualization in BIOS/UEFI"
fi
echo ""

# IOMMU
echo "## IOMMU Support"
if dmesg | grep -qi 'iommu.*enabled' 2>/dev/null; then
  echo "✓ IOMMU enabled"
  dmesg | grep -i iommu | head -3 | sed 's/^/  /'
elif [[ -d /sys/kernel/iommu_groups ]] && [[ -n "$(ls -A /sys/kernel/iommu_groups 2>/dev/null)" ]]; then
  echo "✓ IOMMU groups detected"
  iommu_count=$(ls -1 /sys/kernel/iommu_groups | wc -l)
  echo "  Groups: $iommu_count"
else
  echo "✗ IOMMU not enabled"
  echo "  For Intel: Add kernel parameter: intel_iommu=on iommu=pt"
  echo "  For AMD: Add kernel parameter: amd_iommu=on iommu=pt"
  echo "  Edit: /boot/loader/entries/*.conf or configuration.nix"
fi
echo ""

# Libvirt
echo "## Libvirt Status"
if systemctl is-active --quiet libvirtd 2>/dev/null; then
  echo "✓ libvirtd is running"
  libvirt_version=$(virsh version --daemon 2>/dev/null | grep -i "running hypervisor" | awk '{print $3}' || echo "unknown")
  echo "  Version: $libvirt_version"
  
  if virsh net-info default >/dev/null 2>&1; then
    default_state=$(virsh net-info default 2>/dev/null | grep -E '^Active:' | awk '{print $2}')
    if [[ "$default_state" == "yes" ]]; then
      echo "  ✓ Default network: active"
    else
      echo "  ✗ Default network: inactive"
      echo "    Fix: virsh net-start default"
    fi
  else
    echo "  ✗ Default network: not configured"
    echo "    Fix: virsh net-define /etc/libvirt/qemu/networks/default.xml"
  fi
else
  echo "✗ libvirtd is not running"
  echo "  Fix: systemctl start libvirtd"
  echo "  Enable at boot: systemctl enable libvirtd"
fi
echo ""

# Storage
echo "## Storage Space"
if [[ -d /var/lib/hypervisor ]]; then
  df -h /var/lib/hypervisor 2>/dev/null | tail -1 | awk '{printf "  Total: %s, Used: %s, Available: %s (Use: %s)\n", $2, $3, $4, $5}'
else
  df -h /var/lib 2>/dev/null | tail -1 | awk '{printf "  Total: %s, Used: %s, Available: %s (Use: %s)\n", $2, $3, $4, $5}'
fi

echo ""
echo "Disk usage by directory:"
if [[ -d /var/lib/hypervisor ]]; then
  for dir in /var/lib/hypervisor/*/; do
    if [[ -e "$dir" ]]; then
      size=$(du -sh "$dir" 2>/dev/null | awk '{print $1}')
      dirname=$(basename "$dir")
      echo "  $dirname: $size"
    fi
  done
else
  echo "  No hypervisor directories yet (/var/lib/hypervisor not found)"
fi
echo ""

# Check for low disk space
available_space=$(df /var/lib 2>/dev/null | tail -1 | awk '{print $4}')
if [[ -n "$available_space" ]] && [[ "$available_space" -lt 10485760 ]]; then  # Less than 10GB
  echo "⚠ Warning: Low disk space (< 10GB available)"
  echo "  Consider: sudo nix-collect-garbage -d"
fi
echo ""

# Network bridges
echo "## Network Bridges"
if command -v ip >/dev/null 2>&1; then
  bridge_count=$(ip -br link show type bridge 2>/dev/null | wc -l)
  if [[ "$bridge_count" -gt 0 ]]; then
    echo "✓ Bridges configured: $bridge_count"
    ip -br link show type bridge 2>/dev/null | while read -r line; do
      echo "  $line"
    done
  else
    echo "✗ No bridges configured"
    echo "  To create: Run bridge helper from menu or manually with ip link"
  fi
else
  echo "⚠ 'ip' command not found"
fi
echo ""

# VMs
echo "## Virtual Machines"
vm_profile_count=0
if [[ -d /var/lib/hypervisor/vm_profiles ]]; then
  vm_profile_count=$(ls -1 /var/lib/hypervisor/vm_profiles/*.json 2>/dev/null | wc -l)
fi
echo "VM Profiles: $vm_profile_count"

if command -v virsh >/dev/null 2>&1; then
  running_vms=$(virsh list --name 2>/dev/null | grep -v '^$' | wc -l)
  total_vms=$(virsh list --all --name 2>/dev/null | grep -v '^$' | wc -l)
  echo "Defined VMs: $total_vms"
  echo "Running VMs: $running_vms"
  
  if [[ $total_vms -gt 0 ]]; then
    echo ""
    echo "VM Status:"
    virsh list --all 2>/dev/null | tail -n +3 | while read -r line; do
      if [[ -n "$line" ]]; then
        echo "  $line"
      fi
    done
  fi
else
  echo "⚠ virsh command not found"
fi
echo ""

# AppArmor
echo "## Security"
if command -v aa-status >/dev/null 2>&1; then
  if sudo aa-status >/dev/null 2>&1; then
    echo "✓ AppArmor is active"
    profiles_loaded=$(sudo aa-status 2>/dev/null | grep "profiles are loaded" | awk '{print $1}')
    profiles_enforced=$(sudo aa-status 2>/dev/null | grep "profiles are in enforce mode" | awk '{print $1}')
    echo "  Profiles loaded: $profiles_loaded"
    echo "  Profiles enforced: $profiles_enforced"
    
    # Check for QEMU profile
    if sudo aa-status 2>/dev/null | grep -q "qemu"; then
      echo "  ✓ QEMU AppArmor profile active"
    else
      echo "  ⚠ QEMU AppArmor profile not found"
    fi
  else
    echo "✗ AppArmor not active"
    echo "  Fix: Enable in configuration.nix: security.apparmor.enable = true"
  fi
else
  echo "✗ AppArmor not available"
fi

# Audit daemon
if systemctl is-active --quiet auditd 2>/dev/null; then
  echo "✓ Audit daemon (auditd) is running"
else
  echo "⚠ Audit daemon not running"
  echo "  Enable: security.auditd.enable = true in configuration.nix"
fi
echo ""

# Dependencies check
echo "## Required Dependencies"
required_deps=("jq" "virsh" "qemu-img" "qemu-system-x86_64")
all_present=true
for dep in "${required_deps[@]}"; do
  if command -v "$dep" >/dev/null 2>&1; then
    echo "  ✓ $dep"
  else
    echo "  ✗ $dep (missing)"
    all_present=false
  fi
done

if ! $all_present; then
  echo ""
  echo "  To install missing dependencies on NixOS:"
  echo "  nix-env -iA nixpkgs.jq nixpkgs.libvirt"
fi
echo ""

# Recent errors
echo "## Recent Errors (last 24h)"
if [[ -f /var/lib/hypervisor/logs/menu.log ]]; then
  error_count=$(grep -ci error /var/lib/hypervisor/logs/menu.log 2>/dev/null || echo "0")
  echo "Menu log errors: $error_count"
  if [[ "$error_count" -gt 0 ]]; then
    echo "  Last 5 errors:"
    grep -i error /var/lib/hypervisor/logs/menu.log 2>/dev/null | tail -5 | sed 's/^/    /' || echo "    None"
  fi
else
  echo "Menu log: not found (/var/lib/hypervisor/logs/menu.log)"
fi

if command -v journalctl >/dev/null 2>&1; then
  if journalctl -u libvirtd --since "24 hours ago" >/dev/null 2>&1; then
    libvirt_errors=$(journalctl -u libvirtd --since "24 hours ago" -p err --no-pager 2>/dev/null | grep -c "^" || echo "0")
    echo "Libvirt errors: $libvirt_errors"
    if [[ "$libvirt_errors" -gt 0 ]]; then
      echo "  Last 5 errors:"
      journalctl -u libvirtd --since "24 hours ago" -p err --no-pager 2>/dev/null | tail -5 | sed 's/^/    /'
    fi
  fi
fi
echo ""

# Network connectivity
echo "## Network Connectivity"
if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
  echo "✓ Internet connectivity (can reach 8.8.8.8)"
else
  echo "✗ No internet connectivity"
  echo "  ISO downloads and updates will fail"
  echo "  Check: ip link, ip addr, ip route"
fi
echo ""

# Recommendations
echo "## Recommendations"
recommendations=()

# Check if any VMs are running
if [[ "$running_vms" -eq 0 ]] && [[ "$vm_profile_count" -gt 0 ]]; then
  recommendations+=("Start VMs: No VMs are currently running. Use menu to start VMs.")
fi

# Check available space
if [[ -n "$available_space" ]] && [[ "$available_space" -lt 10485760 ]]; then
  recommendations+=("Free disk space: Run 'sudo nix-collect-garbage -d' to free up space")
fi

# Check if default network is down
if virsh net-info default 2>/dev/null | grep -q "Active:.*no"; then
  recommendations+=("Start default network: virsh net-start default")
fi

# Check for errors
if [[ "$error_count" -gt 10 ]]; then
  recommendations+=("Review errors: Check /var/lib/hypervisor/logs/menu.log for details")
fi

if [[ ${#recommendations[@]} -eq 0 ]]; then
  echo "  ✓ No issues detected - system looks healthy!"
else
  for i in "${!recommendations[@]}"; do
    echo "  $((i+1)). ${recommendations[$i]}"
  done
fi
echo ""

echo "═══════════════════════════════════════════════════════"
echo "Diagnostic report complete"
echo ""
echo "For more help:"
echo "  - View logs: tail -f /var/lib/hypervisor/logs/menu.log"
echo "  - Read docs: ls /etc/hypervisor/docs/"
echo "  - Check libvirt: journalctl -u libvirtd -n 50"
echo "═══════════════════════════════════════════════════════"
