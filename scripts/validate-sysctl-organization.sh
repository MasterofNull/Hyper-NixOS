#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Hyper-NixOS Sysctl Organization Validator
# Prevents duplicate sysctl definitions across modules
#
# ORGANIZATION RULES:
# - kernel.* security sysctls → modules/security/kernel-hardening.nix
# - vm.* / fs.* security hardening sysctls → modules/security/kernel-hardening.nix
# - vm.* / fs.* performance tuning sysctls → modules/core/optimized-system.nix
# - ARM-specific vm.* performance tuning sysctls → modules/core/arm-detection.nix
# - bridge + generic forwarding sysctls used by virtualization → modules/core/hypervisor-base.nix
# - net.core.* and net.ipv4.tcp_* performance sysctls → modules/network-settings/performance.nix
# - net.ipv4.conf.* security sysctls → modules/network-settings/security.nix
# - net.ipv4.icmp_* security sysctls → modules/network-settings/security.nix
# - net.ipv4.tcp_syncookies → modules/network-settings/security.nix

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Validating sysctl organization..."

# Extract all sysctl definitions (excluding comments and lib.mkForce overrides in strict.nix)
declare -A sysctl_files
duplicates=0

is_allowed_duplicate() {
  local sysctl="$1"
  local file1="$2"
  local file2="$3"
  local allowed_profile_files=(
    "modules/core/optimized-system.nix"
    "modules/core/arm-detection.nix"
    "modules/hardware/desktop.nix"
    "modules/hardware/server.nix"
    "modules/network-settings/performance.nix"
    "modules/network-settings/performance-tuning.nix"
  )
  local file1_allowed=false
  local file2_allowed=false

  for allowed in "${allowed_profile_files[@]}"; do
    if [[ "$file1" == *"$allowed" ]]; then
      file1_allowed=true
    fi
    if [[ "$file2" == *"$allowed" ]]; then
      file2_allowed=true
    fi
  done

  case "$sysctl" in
    vm.swappiness|vm.dirty_ratio|vm.dirty_background_ratio|vm.vfs_cache_pressure|vm.overcommit_memory|vm.overcommit_ratio)
      if [[ "$file1_allowed" == true && "$file2_allowed" == true ]]; then
        return 0
      fi
      ;;
    net.core.*|net.ipv4.tcp_*|net.ipv4.tcp_congestion|net.ipv4.tcp_congestion_control)
      if [[ "$file1_allowed" == true && "$file2_allowed" == true ]]; then
        return 0
      fi
      ;;
    fs.file-max|fs.inotify.max_user_watches|fs.aio-max-nr)
      if [[ "$file1_allowed" == true && "$file2_allowed" == true ]]; then
        return 0
      fi
      ;;
  esac

  return 1
}

while IFS= read -r line; do
  # Only process lines with sysctl definitions (skip lib.mkForce in strict.nix)
  if [[ "$line" == *"strict.nix"* ]] || [[ "$line" != *'"'*'='* ]]; then
    continue
  fi
  
  file=$(echo "$line" | cut -d: -f1)
  # Extract sysctl name (first quoted string before =)
  sysctl=$(echo "$line" | grep -oP '"\K[a-z][a-z0-9._]*(?="\s*=)' | head -1)
  
  if [[ -z "$sysctl" ]]; then
    continue
  fi
  
  if [[ -n "${sysctl_files[$sysctl]:-}" ]]; then
    if is_allowed_duplicate "$sysctl" "${sysctl_files[$sysctl]}" "$file"; then
      continue
    fi
    echo -e "${RED}✗ DUPLICATE FOUND${NC}"
    echo -e "  Sysctl: ${YELLOW}$sysctl${NC}"
    echo -e "  File 1: ${sysctl_files[$sysctl]}"
    echo -e "  File 2: $file"
    echo ""
    ((duplicates++))
  else
    sysctl_files[$sysctl]=$file
  fi
done < <(grep -rE '^\s*"[a-z][a-z0-9._]*"\s*=' modules/ --include="*.nix")

# Verify organization rules
echo ""
echo "Checking organization rules..."

violations=0

for sysctl in "${!sysctl_files[@]}"; do
  file="${sysctl_files[$sysctl]}"
  
  # kernel.* security sysctls belong in kernel-hardening, but scheduler/NUMA
  # performance tuning can live in tuned desktop/server profiles.
  if [[ "$sysctl" =~ ^kernel\. ]] &&
     [[ "$sysctl" != "kernel.numa_balancing" ]] &&
     [[ "$sysctl" != kernel.sched_* ]] &&
     [[ "$file" != *"kernel-hardening.nix"* ]]; then
    echo -e "${RED}✗ WRONG LOCATION${NC}"
    echo -e "  Sysctl: ${YELLOW}$sysctl${NC}"
    echo -e "  Current: $file"
    echo -e "  Expected: modules/security/kernel-hardening.nix"
    echo ""
    ((violations++))
  fi

  if [[ "$sysctl" == "kernel.numa_balancing" ]]; then
    if [[ "$file" == *"kernel-hardening.nix"* ]] || [[ "$file" == *"modules/hardware/server.nix"* ]]; then
      :
    else
      echo -e "${RED}✗ WRONG LOCATION${NC}"
      echo -e "  Sysctl: ${YELLOW}$sysctl${NC}"
      echo -e "  Current: $file"
      echo -e "  Expected: modules/security/kernel-hardening.nix or modules/hardware/server.nix"
      echo ""
      ((violations++))
    fi
  fi

  if [[ "$sysctl" == kernel.sched_* ]]; then
    if [[ "$file" == *"kernel-hardening.nix"* ]] || [[ "$file" == *"modules/hardware/desktop.nix"* ]]; then
      :
    else
      echo -e "${RED}✗ WRONG LOCATION${NC}"
      echo -e "  Sysctl: ${YELLOW}$sysctl${NC}"
      echo -e "  Current: $file"
      echo -e "  Expected: modules/security/kernel-hardening.nix or modules/hardware/desktop.nix"
      echo ""
      ((violations++))
    fi
  fi
  
  # vm.* tuning can live in optimized-system or arm-detection; security defaults
  # belong in kernel-hardening.nix.
  if [[ "$sysctl" =~ ^vm\. ]] && [[ "$sysctl" != "vm.nr_hugepages" ]]; then
    if [[ "$file" == *"kernel-hardening.nix"* ]] || [[ "$file" == *"core/optimized-system.nix"* ]] || [[ "$file" == *"core/arm-detection.nix"* ]] || [[ "$file" == *"hardware/server.nix"* ]]; then
      :
    else
      echo -e "${RED}✗ WRONG LOCATION${NC}"
      echo -e "  Sysctl: ${YELLOW}$sysctl${NC}"
      echo -e "  Current: $file"
      echo -e "  Expected: modules/security/kernel-hardening.nix, modules/core/optimized-system.nix, modules/core/arm-detection.nix, or modules/hardware/server.nix"
      echo ""
      ((violations++))
    fi
  fi
  
  # fs.* security hardening belongs in kernel-hardening, while capacity tuning
  # lives in optimized-system.
  if [[ "$sysctl" =~ ^fs\. ]]; then
    if [[ "$file" == *"kernel-hardening.nix"* ]] || [[ "$file" == *"core/optimized-system.nix"* ]]; then
      :
    else
      echo -e "${RED}✗ WRONG LOCATION${NC}"
      echo -e "  Sysctl: ${YELLOW}$sysctl${NC}"
      echo -e "  Current: $file"
      echo -e "  Expected: modules/security/kernel-hardening.nix or modules/core/optimized-system.nix"
      echo ""
      ((violations++))
    fi
  fi
  
  # Performance-related network sysctls may be owned by the shared network
  # modules or by tuned system/profile modules.
  if [[ "$sysctl" =~ ^net\.core\. ]] || [[ "$sysctl" =~ ^net\.ipv4\.tcp_ ]] && [[ "$sysctl" != "net.ipv4.tcp_syncookies" ]]; then
    if [[ "$file" != *"network-settings/performance.nix"* ]] &&
       [[ "$file" != *"network-settings/performance-tuning.nix"* ]] &&
       [[ "$file" != *"core/optimized-system.nix"* ]] &&
       [[ "$file" != *"hardware/desktop.nix"* ]] &&
       [[ "$file" != *"hardware/server.nix"* ]]; then
      echo -e "${RED}✗ WRONG LOCATION${NC}"
      echo -e "  Sysctl: ${YELLOW}$sysctl${NC}"
      echo -e "  Current: $file"
      echo -e "  Expected: a network performance module or tuned system/profile module"
      echo ""
      ((violations++))
    fi
  fi
  
  # net.ipv4.conf.*, net.ipv4.icmp_*, and tcp_syncookies must be in network-settings/security.nix
  if [[ "$sysctl" =~ ^net\.ipv4\.conf\. ]] || [[ "$sysctl" =~ ^net\.ipv4\.icmp_ ]] || [[ "$sysctl" == "net.ipv4.tcp_syncookies" ]]; then
    if [[ "$file" != *"network-settings/security.nix"* ]]; then
      echo -e "${RED}✗ WRONG LOCATION${NC}"
      echo -e "  Sysctl: ${YELLOW}$sysctl${NC}"
      echo -e "  Current: $file"
      echo -e "  Expected: modules/network-settings/security.nix"
      echo ""
      ((violations++))
    fi
  fi

  # Bridge filtering and generic forwarding are part of the virtualization base.
  if [[ "$sysctl" == "net.bridge.bridge-nf-call-iptables" ]] || [[ "$sysctl" == "net.bridge.bridge-nf-call-ip6tables" ]] || [[ "$sysctl" == "net.ipv4.ip_forward" ]]; then
    if [[ "$file" == *"core/hypervisor-base.nix"* ]] || [[ "$file" == *"network-settings/"* ]]; then
      :
    else
      echo -e "${RED}✗ WRONG LOCATION${NC}"
      echo -e "  Sysctl: ${YELLOW}$sysctl${NC}"
      echo -e "  Current: $file"
      echo -e "  Expected: modules/core/hypervisor-base.nix or a network-settings module"
      echo ""
      ((violations++))
    fi
  fi
done

# Summary
echo ""
echo "════════════════════════════════════════"
if [[ $duplicates -eq 0 ]] && [[ $violations -eq 0 ]]; then
  echo -e "${GREEN}✓ All sysctl definitions are properly organized${NC}"
  echo -e "${GREEN}✓ No duplicates found${NC}"
  exit 0
else
  echo -e "${RED}✗ Found $duplicates duplicate(s)${NC}"
  echo -e "${RED}✗ Found $violations organization violation(s)${NC}"
  echo ""
  echo "Organization rules:"
  echo "  kernel.* → modules/security/kernel-hardening.nix"
  echo "  vm.*, fs.* hardening → modules/security/kernel-hardening.nix"
  echo "  vm.*, fs.* performance → modules/core/optimized-system.nix"
  echo "  ARM vm.* performance → modules/core/arm-detection.nix"
  echo "  net.bridge.*, net.ipv4.ip_forward → modules/core/hypervisor-base.nix or network-settings/*"
  echo "  net.core.*, net.ipv4.tcp_* (perf) → modules/network-settings/performance.nix"
  echo "  net.ipv4.conf.*, net.ipv4.icmp_* (security) → modules/network-settings/security.nix"
  exit 1
fi
