#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Hyper-NixOS Installation Validator
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Validates hypervisor installation and configuration
# Checks system files, services, and configuration integrity
#
set -Eeuo pipefail
IFS=$'\n\t'
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

msg() { printf "${BLUE}[validator]${NC} %s\n" "$*"; }
pass() { printf "${GREEN}✓${NC} %s\n" "$*"; ((PASSED++)); }
fail() { printf "${RED}✗${NC} %s\n" "$*"; ((FAILED++)); }
warn() { printf "${YELLOW}⚠${NC} %s\n" "$*"; ((WARNINGS++)); }

usage() {
  cat <<USAGE
Usage: $(basename "$0") [OPTIONS]

Validate Hyper-NixOS hypervisor installation and configuration.

Options:
  --quick             Quick validation (skip optional checks)
  --fix               Attempt to fix common issues
  --verbose           Show detailed output
  -h, --help          Show this help

Exit codes:
  0 - All checks passed
  1 - Critical failures detected
  2 - Warnings present but no failures

USAGE
}

QUICK=false
FIX=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quick) QUICK=true; shift;;
    --fix) FIX=true; shift;;
    --verbose) VERBOSE=true; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1" >&2; usage; exit 1;;
  esac
done

msg "Hyper-NixOS Installation Validator"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check 1: Core directories
msg "Checking core directories..."
for dir in /etc/hypervisor /etc/hypervisor/src /var/lib/hypervisor; do
  if [[ -d "$dir" ]]; then
    pass "$dir exists"
  else
    fail "$dir is missing"
    if $FIX; then
      msg "  Attempting to create $dir..."
      mkdir -p "$dir" && pass "  Created $dir" || fail "  Failed to create $dir"
    fi
  fi
done

# Check 2: Critical files
msg "Checking critical configuration files..."
critical_files=(
  "/etc/hypervisor/flake.nix"
  "/etc/hypervisor/src/configuration.nix"
  "/etc/nixos/configuration/core/hardware-configuration.nix"
)

for file in "${critical_files[@]}"; do
  if [[ -f "$file" ]]; then
    pass "$file exists"
  else
    fail "$file is missing"
  fi
done

# Check 3: Flake configuration
msg "Checking flake configuration..."
if [[ -f /etc/hypervisor/flake.nix ]]; then
  if grep -q "hypervisor.url" /etc/hypervisor/flake.nix; then
    pass "Flake has hypervisor input configured"
  else
    fail "Flake missing hypervisor input"
  fi
  
  if grep -q "nixosConfigurations" /etc/hypervisor/flake.nix; then
    pass "Flake has nixosConfigurations"
  else
    fail "Flake missing nixosConfigurations"
  fi
fi

# Check 4: Scripts directory
msg "Checking scripts..."
if [[ -d /etc/hypervisor/src/scripts ]]; then
  local script_count
  script_count=$(find /etc/hypervisor/src/scripts -type f -name "*.sh" | wc -l)
  if [[ $script_count -gt 0 ]]; then
    pass "Found $script_count shell scripts"
    
    # Check if scripts are executable
    local non_executable
    non_executable=$(find /etc/hypervisor/src/scripts -type f -name "*.sh" ! -perm -u+x | wc -l)
    if [[ $non_executable -gt 0 ]]; then
      warn "$non_executable scripts are not executable"
      if $FIX; then
        msg "  Making scripts executable..."
        find /etc/hypervisor/src/scripts -type f -name "*.sh" -exec chmod +x {} \;
        pass "  Fixed script permissions"
      fi
    else
      pass "All scripts are executable"
    fi
  else
    warn "No shell scripts found"
  fi
fi

# Check 5: User configuration
msg "Checking user configuration..."
if [[ -f /etc/hypervisor/src/modules/users-local.nix ]]; then
  pass "users-local.nix exists"
  
  # Check if it has actual user definitions
  if grep -q "users.users" /etc/hypervisor/src/modules/users-local.nix; then
    pass "User definitions found"
  else
    warn "No user definitions in users-local.nix"
  fi
else
  warn "users-local.nix not found (will be generated on rebuild)"
fi

# Check 6: System configuration
msg "Checking system configuration..."
if [[ -f /etc/hypervisor/src/modules/system-local.nix ]]; then
  pass "system-local.nix exists"
else
  warn "system-local.nix not found (will be generated on rebuild)"
fi

# Check 7: Nix experimental features
msg "Checking Nix configuration..."
if nix --version >/dev/null 2>&1; then
  pass "Nix is available"
  
  if nix flake --help >/dev/null 2>&1; then
    pass "Nix flakes are enabled"
  else
    fail "Nix flakes are not enabled"
  fi
else
  fail "Nix is not available"
fi

# Check 8: Virtualization support
msg "Checking virtualization support..."
if [[ -e /dev/kvm ]]; then
  pass "/dev/kvm exists (KVM available)"
else
  fail "/dev/kvm not found (KVM not available)"
fi

if command -v virsh >/dev/null 2>&1; then
  pass "virsh command is available"
else
  warn "virsh not found (libvirt may not be installed yet)"
fi

# Check 9: Network configuration (quick check)
if ! $QUICK; then
  msg "Checking network configuration..."
  
  if ip link show br0 >/dev/null 2>&1; then
    pass "Bridge br0 exists"
  else
    warn "Bridge br0 not configured (run network setup)"
  fi
  
  if systemctl is-enabled libvirtd >/dev/null 2>&1; then
    pass "libvirtd service is enabled"
  else
    warn "libvirtd service not enabled"
  fi
fi

# Check 10: Required tools
msg "Checking required tools..."
required_tools=(curl wget git jq rsync)
for tool in "${required_tools[@]}"; do
  if command -v "$tool" >/dev/null 2>&1; then
    pass "$tool is available"
  else
    warn "$tool is not available (recommended)"
  fi
done

# Check 11: File integrity (sample check)
if ! $QUICK; then
  msg "Checking file integrity (sample)..."
  
  # Check if flake.lock is coherent
  if [[ -f /etc/hypervisor/flake.lock ]]; then
    if jq empty /etc/hypervisor/flake.lock >/dev/null 2>&1; then
      pass "flake.lock is valid JSON"
    else
      fail "flake.lock is corrupted"
      if $FIX; then
        msg "  Regenerating flake.lock..."
        nix flake lock /etc/hypervisor && pass "  Regenerated flake.lock" || fail "  Failed to regenerate"
      fi
    fi
  else
    warn "flake.lock not found (will be created on first build)"
  fi
fi

# Check 12: Permissions
if ! $QUICK; then
  msg "Checking permissions..."
  
  if [[ -d /etc/hypervisor/src ]]; then
    local owner
    owner=$(stat -c %U /etc/hypervisor/src 2>/dev/null || stat -f %Su /etc/hypervisor/src 2>/dev/null)
    if [[ "$owner" == "root" ]]; then
      pass "/etc/hypervisor/src owned by root"
    else
      warn "/etc/hypervisor/src owned by $owner (should be root)"
      if $FIX; then
        msg "  Fixing ownership..."
        chown -R root:root /etc/hypervisor/src && pass "  Fixed ownership" || fail "  Failed to fix ownership"
      fi
    fi
  fi
fi

# Check 13: Disk space
msg "Checking disk space..."
local available_gb
if command -v df >/dev/null 2>&1; then
  available_gb=$(df -BG /etc/hypervisor | tail -1 | awk '{print $4}' | sed 's/G//')
  if [[ $available_gb -gt 10 ]]; then
    pass "Sufficient disk space (${available_gb}GB available)"
  elif [[ $available_gb -gt 5 ]]; then
    warn "Low disk space (${available_gb}GB available, recommend 10GB+)"
  else
    fail "Critically low disk space (${available_gb}GB available)"
  fi
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
msg "Validation Summary:"
pass "$PASSED checks passed"
if [[ $WARNINGS -gt 0 ]]; then
  warn "$WARNINGS warnings"
fi
if [[ $FAILED -gt 0 ]]; then
  fail "$FAILED checks failed"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Exit code
if [[ $FAILED -gt 0 ]]; then
  msg "❌ Critical issues detected - installation may not work correctly"
  if ! $FIX; then
    msg "Run with --fix to attempt automatic repairs"
  fi
  exit 1
elif [[ $WARNINGS -gt 0 ]]; then
  msg "⚠️  Warnings present - system should work but some features may be limited"
  exit 2
else
  msg "✅ All checks passed - installation is healthy!"
  exit 0
fi
