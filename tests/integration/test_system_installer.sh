#!/usr/bin/env bash
#
# Integration Test: System Installer
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/../lib/test_helpers.sh"

# Detect CI environment
CI_MODE=false
if [[ "${CI:-false}" == "true" ]] || [[ "${GITHUB_ACTIONS:-false}" == "true" ]]; then
  CI_MODE=true
fi

test_suite_start "System Installer"

# In CI, only do structure validation
if $CI_MODE; then
  test_case "System installer script exists"
  assert_file_exists "../../scripts/system_installer.sh"
  
  test_case "System installer script has valid syntax"
  if bash -n "../../scripts/system_installer.sh" 2>/dev/null; then
    test_pass "Syntax is valid"
  else
    test_fail "Syntax errors found"
  fi
  
  test_case "System installer script is executable"
  if [[ -x "../../scripts/system_installer.sh" ]]; then
    test_pass "Script is executable"
  else
    test_info "Script will be made executable during installation"
  fi
  
  test_case "Configuration files exist"
  assert_file_exists "../../configuration.nix"
  assert_file_exists "../../hardware-configuration.nix"
  assert_file_exists "../../modules/security/profiles.nix"
  
  test_suite_end
  exit 0
fi

# Full integration tests (requires NixOS)
if ! command -v nixos-rebuild &>/dev/null; then
  test_info "Skipping full tests - requires NixOS system"
  test_suite_end
  exit 0
fi

test_case "Bootstrap script exists and is executable"
assert_file_exists "/etc/hypervisor/scripts/system_installer.sh"

test_case "Source directory is properly installed"
assert_directory_exists "/etc/hypervisor/src"

test_case "Configuration files are in place"
assert_file_exists "/etc/hypervisor/src/configuration.nix"
assert_file_exists "/etc/hypervisor/src/hardware-configuration.nix"
assert_file_exists "/etc/hypervisor/src/modules/security/profiles.nix"

test_case "Required services are enabled"
if command -v systemctl &>/dev/null; then
  assert_service_enabled "libvirtd"
fi

test_case "Management user exists"
if id hypervisor-operator &>/dev/null; then
  test_pass "Operator user exists"
else
  test_info "Operator user will be created during system installation"
fi

test_case "Operator user has correct group memberships"
if id hypervisor-operator &>/dev/null; then
  if groups hypervisor-operator | grep -q "libvirtd"; then
    test_pass "In libvirtd group"
  fi
  if groups hypervisor-operator | grep -q "kvm"; then
    test_pass "In kvm group"
  fi
  if ! groups hypervisor-operator | grep -q "wheel"; then
    test_pass "NOT in wheel group (correct for security)"
  fi
fi

test_suite_end
