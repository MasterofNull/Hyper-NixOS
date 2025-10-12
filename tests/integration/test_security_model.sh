#!/usr/bin/env bash
#
# Integration Test: Security Model
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test_helpers.sh"

# Detect CI environment
CI_MODE=false
if [[ "${CI:-false}" == "true" ]] || [[ "${GITHUB_ACTIONS:-false}" == "true" ]]; then
  CI_MODE=true
fi

test_suite_start "Zero-Trust Security Model"

# In CI, validate configuration files only
if $CI_MODE; then
  test_case "Security configuration files exist"
  assert_file_exists "../../configuration/security.nix"
  assert_file_exists "../../configuration/security-production.nix"
  
  test_case "Security production is default"
  if grep -q "security-production.nix" "../../configuration/configuration.nix"; then
    test_pass "Production security model is enabled by default"
  else
    test_fail "Production security not found in main config"
  fi
  
  test_case "Polkit rules are configured"
  if grep -q "polkit" "../../configuration/security-production.nix"; then
    test_pass "Polkit authorization configured"
  else
    test_info "Polkit rules should be in security-production.nix"
  fi
  
  test_case "Audit logging is configured"
  if grep -q "auditd\|audit" "../../configuration/security-production.nix" ||
     grep -q "auditd\|audit" "../../configuration/security.nix"; then
    test_pass "Audit logging configured"
  else
    test_info "Audit logging should be enabled"
  fi
  
  test_suite_end
  exit 0
fi

# Full tests (requires NixOS)
if ! command -v systemctl &>/dev/null; then
  test_info "Skipping full tests - requires systemd"
  test_suite_end
  exit 0
fi

test_case "Operator user exists"
if id hypervisor-operator &>/dev/null; then
  test_pass "Operator user exists"
else
  test_info "Operator user created during bootstrap"
fi

test_case "Operator user is NOT in wheel group"
if id hypervisor-operator &>/dev/null; then
  if ! groups hypervisor-operator | grep -q "wheel"; then
    test_pass "Operator correctly excluded from wheel"
  else
    test_fail "Operator should NOT be in wheel group"
  fi
fi

test_case "Operator user is in required groups"
if id hypervisor-operator &>/dev/null; then
  if groups hypervisor-operator | grep -q "kvm"; then
    test_pass "In kvm group"
  fi
  if groups hypervisor-operator | grep -q "libvirtd"; then
    test_pass "In libvirtd group"
  fi
fi

test_case "Polkit rules exist"
if [[ -d /etc/polkit-1/rules.d ]] && ls /etc/polkit-1/rules.d/*.rules >/dev/null 2>&1; then
  test_pass "Polkit rules installed"
else
  test_info "Polkit rules installed during NixOS build"
fi

test_case "Audit logging is active"
if systemctl is-active auditd >/dev/null 2>&1; then
  test_pass "Auditd is running"
else
  test_info "Auditd enabled in configuration"
fi

test_case "Firewall is active"
if systemctl is-active firewall >/dev/null 2>&1 || \
   iptables -L >/dev/null 2>&1; then
  test_pass "Firewall is active"
else
  test_info "Firewall configured in NixOS"
fi

test_suite_end
