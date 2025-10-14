#!/usr/bin/env bash
#
# Hyper-NixOS Sysctl Organization Validator
# Prevents duplicate sysctl definitions across modules
#
# ORGANIZATION RULES:
# - kernel.* sysctls → modules/security/kernel-hardening.nix
# - vm.* sysctls → modules/security/kernel-hardening.nix (except vm.nr_hugepages in virtualization/performance.nix)
# - fs.* sysctls → modules/security/kernel-hardening.nix
# - net.core.* performance sysctls → modules/network-settings/performance.nix
# - net.ipv4.tcp_* performance sysctls → modules/network-settings/performance.nix
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
  
  # kernel.* must be in kernel-hardening.nix
  if [[ "$sysctl" =~ ^kernel\. ]] && [[ "$file" != *"kernel-hardening.nix"* ]]; then
    echo -e "${RED}✗ WRONG LOCATION${NC}"
    echo -e "  Sysctl: ${YELLOW}$sysctl${NC}"
    echo -e "  Current: $file"
    echo -e "  Expected: modules/security/kernel-hardening.nix"
    echo ""
    ((violations++))
  fi
  
  # vm.* must be in kernel-hardening.nix (except vm.nr_hugepages)
  if [[ "$sysctl" =~ ^vm\. ]] && [[ "$sysctl" != "vm.nr_hugepages" ]] && [[ "$file" != *"kernel-hardening.nix"* ]]; then
    echo -e "${RED}✗ WRONG LOCATION${NC}"
    echo -e "  Sysctl: ${YELLOW}$sysctl${NC}"
    echo -e "  Current: $file"
    echo -e "  Expected: modules/security/kernel-hardening.nix"
    echo ""
    ((violations++))
  fi
  
  # fs.* must be in kernel-hardening.nix
  if [[ "$sysctl" =~ ^fs\. ]] && [[ "$file" != *"kernel-hardening.nix"* ]]; then
    echo -e "${RED}✗ WRONG LOCATION${NC}"
    echo -e "  Sysctl: ${YELLOW}$sysctl${NC}"
    echo -e "  Current: $file"
    echo -e "  Expected: modules/security/kernel-hardening.nix"
    echo ""
    ((violations++))
  fi
  
  # net.core.* and net.ipv4.tcp_* (except tcp_syncookies) must be in network-settings/performance.nix
  if [[ "$sysctl" =~ ^net\.core\. ]] || [[ "$sysctl" =~ ^net\.ipv4\.tcp_ ]] && [[ "$sysctl" != "net.ipv4.tcp_syncookies" ]]; then
    if [[ "$file" != *"network-settings/performance.nix"* ]]; then
      echo -e "${RED}✗ WRONG LOCATION${NC}"
      echo -e "  Sysctl: ${YELLOW}$sysctl${NC}"
      echo -e "  Current: $file"
      echo -e "  Expected: modules/network-settings/performance.nix"
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
  echo "  kernel.*, vm.*, fs.* → modules/security/kernel-hardening.nix"
  echo "  net.core.*, net.ipv4.tcp_* (perf) → modules/network-settings/performance.nix"
  echo "  net.ipv4.conf.*, net.ipv4.icmp_* (security) → modules/network-settings/security.nix"
  exit 1
fi
