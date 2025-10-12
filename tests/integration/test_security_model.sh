#!/usr/bin/env bash
#
# Integration Test: Security Model
# Tests zero-trust security configuration
#

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TEST_DIR/lib/test_helpers.sh"

test_operator_user_exists() {
  test_start "Operator user exists"
  
  if id hypervisor-operator >/dev/null 2>&1; then
    test_pass "Operator user exists"
  else
    test_fail "Operator user does not exist"
  fi
}

test_operator_not_in_wheel() {
  test_start "Operator not in wheel group (no sudo)"
  
  if id -nG hypervisor-operator | grep -qw wheel; then
    test_fail "Operator is in wheel group (has sudo)"
  else
    test_pass "Operator not in wheel group"
  fi
}

test_operator_in_required_groups() {
  test_start "Operator in required groups"
  
  local required_groups=("kvm" "libvirtd")
  local all_present=true
  
  for group in "${required_groups[@]}"; do
    if ! id -nG hypervisor-operator | grep -qw "$group"; then
      test_fail "Operator not in $group group"
      all_present=false
    fi
  done
  
  if $all_present; then
    test_pass "Operator in all required groups"
  fi
}

test_polkit_rules_exist() {
  test_start "Polkit rules configured"
  
  if [[ -f /etc/polkit-1/rules.d/50-libvirt-operator.rules ]]; then
    test_pass "Polkit rules exist"
  else
    test_fail "Polkit rules missing"
  fi
}

test_audit_logging_enabled() {
  test_start "Audit logging enabled"
  
  if systemctl is-active auditd >/dev/null 2>&1; then
    test_pass "Auditd is active"
  else
    test_fail "Auditd is not active"
  fi
}

test_firewall_enabled() {
  test_start "Firewall is enabled"
  
  if systemctl is-active firewalld >/dev/null 2>&1 || \
     iptables -L >/dev/null 2>&1; then
    test_pass "Firewall is active"
  else
    test_fail "Firewall is not active"
  fi
}

test_ssh_password_auth_disabled() {
  test_start "SSH password authentication disabled"
  
  if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config 2>/dev/null; then
    test_pass "SSH password auth disabled"
  else
    test_warn "SSH password auth may be enabled"
  fi
}

# Run tests
main() {
  test_suite_start "Security Model"
  
  test_operator_user_exists
  test_operator_not_in_wheel
  test_operator_in_required_groups
  test_polkit_rules_exist
  test_audit_logging_enabled
  test_firewall_enabled
  test_ssh_password_auth_disabled
  
  test_suite_end
}

main "$@"
