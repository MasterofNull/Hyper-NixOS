#!/usr/bin/env bash
#
# Integration Test: Bootstrap Installation
# Tests the complete bootstrap process
#

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TEST_DIR/lib/test_helpers.sh"

test_bootstrap_completes() {
  test_start "Bootstrap script completes successfully"
  
  # Mock bootstrap (in real CI, would run actual bootstrap)
  if [[ -f /etc/hypervisor/flake.nix ]]; then
    test_pass "Bootstrap completed"
  else
    test_fail "Bootstrap did not complete"
  fi
}

test_configuration_files_exist() {
  test_start "Required configuration files exist"
  
  local required_files=(
    "/etc/hypervisor/flake.nix"
    "/etc/hypervisor/src/configuration/configuration.nix"
    "/etc/hypervisor/src/configuration/security-production.nix"
    "/var/lib/hypervisor/configuration/users-local.nix"
  )
  
  for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
      test_pass "Found: $file"
    else
      test_fail "Missing: $file"
    fi
  done
}

test_services_enabled() {
  test_start "Required services are enabled"
  
  local services=(
    "hypervisor-menu"
    "libvirtd"
  )
  
  for service in "${services[@]}"; do
    if systemctl is-enabled "$service" >/dev/null 2>&1; then
      test_pass "Service enabled: $service"
    else
      test_fail "Service not enabled: $service"
    fi
  done
}

test_user_in_correct_groups() {
  test_start "Operator user has correct groups"
  
  local user="hypervisor-operator"
  local required_groups=("kvm" "libvirtd")
  
  if ! id "$user" >/dev/null 2>&1; then
    test_fail "User $user does not exist"
    return
  fi
  
  for group in "${required_groups[@]}"; do
    if id -nG "$user" | grep -qw "$group"; then
      test_pass "User in group: $group"
    else
      test_fail "User not in group: $group"
    fi
  done
}

# Run tests
main() {
  test_suite_start "Bootstrap Installation"
  
  test_bootstrap_completes
  test_configuration_files_exist
  test_services_enabled
  test_user_in_correct_groups
  
  test_suite_end
}

main "$@"
