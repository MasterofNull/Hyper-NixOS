#!/usr/bin/env bash
#
# Test Privilege Separation
# Sudo Required: NO (for basic tests), YES (for system tests)
#
# Copyright (c) 2025 Hyper-NixOS Contributors
# License: MIT
#
# This script tests the privilege separation model to ensure:
# - VM operations work without sudo
# - System operations require sudo
# - Proper error messages are shown
#

set -Eeuo pipefail

# Source test framework
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${TEST_DIR}/lib/test_framework.sh"
source "${TEST_DIR}/../scripts/lib/common.sh"
source "${TEST_DIR}/../scripts/lib/exit_codes.sh"

# Test configuration
readonly TEST_VM_NAME="test-privilege-vm"
readonly TEST_USER=$(get_actual_user)

# Test results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[0;33m'
readonly NC='\033[0m' # No Color

# Test result logging
log_test_result() {
    local test_name="$1"
    local result="$2"
    local message="${3:-}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$result" == "PASS" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} $test_name"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} $test_name"
        if [[ -n "$message" ]]; then
            echo "  Error: $message"
        fi
    fi
}

# Test: Check if user is in libvirtd group
test_libvirtd_group() {
    local test_name="User in libvirtd group"
    
    if groups | grep -q '\blibvirtd\b'; then
        log_test_result "$test_name" "PASS"
    else
        log_test_result "$test_name" "FAIL" "User $TEST_USER not in libvirtd group"
    fi
}

# Test: VM operations without sudo
test_vm_operations_no_sudo() {
    echo
    echo "=== Testing VM Operations (No Sudo) ==="
    
    # Test 1: List VMs without sudo
    local test_name="List VMs without sudo"
    if virsh --connect qemu:///system list --all &>/dev/null; then
        log_test_result "$test_name" "PASS"
    else
        log_test_result "$test_name" "FAIL" "Cannot list VMs without sudo"
    fi
    
    # Test 2: Check VM info without sudo
    test_name="Get VM info without sudo"
    if virsh --connect qemu:///system list --name | head -1 | read -r vm_name && [[ -n "$vm_name" ]]; then
        if virsh --connect qemu:///system dominfo "$vm_name" &>/dev/null; then
            log_test_result "$test_name" "PASS"
        else
            log_test_result "$test_name" "FAIL" "Cannot get VM info without sudo"
        fi
    else
        log_test_result "$test_name" "SKIP" "No VMs available to test"
    fi
    
    # Test 3: Access libvirt socket
    test_name="Access libvirt socket"
    if [[ -S /var/run/libvirt/libvirt-sock ]] && [[ -w /var/run/libvirt/libvirt-sock ]]; then
        log_test_result "$test_name" "PASS"
    else
        log_test_result "$test_name" "FAIL" "Cannot access libvirt socket"
    fi
}

# Test: Script privilege checks
test_script_privilege_checks() {
    echo
    echo "=== Testing Script Privilege Checks ==="
    
    # Test VM start script
    local test_name="VM start script privilege check"
    if "${TEST_DIR}/../scripts/vm_start.sh" --help &>/dev/null; then
        log_test_result "$test_name" "PASS"
    else
        log_test_result "$test_name" "FAIL" "VM start script failed privilege check"
    fi
    
    # Test system config script without sudo (should fail)
    test_name="System config without sudo (should fail)"
    if ! "${TEST_DIR}/../scripts/system_config.sh" show 2>&1 | grep -q "requires administrator privileges"; then
        log_test_result "$test_name" "FAIL" "System config should require sudo"
    else
        log_test_result "$test_name" "PASS"
    fi
}

# Test: Privilege functions
test_privilege_functions() {
    echo
    echo "=== Testing Privilege Functions ==="
    
    # Test get_actual_user
    local test_name="get_actual_user function"
    local user=$(get_actual_user)
    if [[ -n "$user" ]]; then
        log_test_result "$test_name" "PASS"
        echo "  Detected user: $user"
    else
        log_test_result "$test_name" "FAIL" "Cannot determine actual user"
    fi
    
    # Test is_running_as_sudo
    test_name="is_running_as_sudo function"
    if is_running_as_sudo; then
        if [[ $EUID -eq 0 ]] || [[ -n "$SUDO_USER" ]]; then
            log_test_result "$test_name" "PASS"
        else
            log_test_result "$test_name" "FAIL" "False positive for sudo detection"
        fi
    else
        if [[ $EUID -ne 0 ]] && [[ -z "$SUDO_USER" ]]; then
            log_test_result "$test_name" "PASS"
        else
            log_test_result "$test_name" "FAIL" "Failed to detect sudo"
        fi
    fi
    
    # Test operation_requires_sudo
    test_name="operation_requires_sudo function"
    local pass=true
    
    # VM operations should not require sudo
    for op in vm_start vm_stop vm_list; do
        if operation_requires_sudo "$op"; then
            pass=false
            echo "  ERROR: $op should not require sudo"
        fi
    done
    
    # System operations should require sudo
    for op in system_config network_setup security_audit; do
        if ! operation_requires_sudo "$op"; then
            pass=false
            echo "  ERROR: $op should require sudo"
        fi
    done
    
    if [[ "$pass" == "true" ]]; then
        log_test_result "$test_name" "PASS"
    else
        log_test_result "$test_name" "FAIL"
    fi
}

# Test: File permissions
test_file_permissions() {
    echo
    echo "=== Testing File Permissions ==="
    
    # Test VM directories
    local test_name="VM directory permissions"
    local vm_dirs=(
        "/var/lib/hypervisor/vms"
        "/var/lib/hypervisor/backups"
        "/var/lib/hypervisor/snapshots"
    )
    
    local all_good=true
    for dir in "${vm_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            if [[ -r "$dir" ]] && [[ -w "$dir" ]]; then
                echo "  ✓ $dir is accessible"
            else
                echo "  ✗ $dir is not accessible"
                all_good=false
            fi
        fi
    done
    
    if [[ "$all_good" == "true" ]]; then
        log_test_result "$test_name" "PASS"
    else
        log_test_result "$test_name" "WARN" "Some directories not accessible"
    fi
    
    # Test system directories (should not be writable)
    test_name="System directory protection"
    local sys_dirs=(
        "/etc/hypervisor"
        "/var/lib/hypervisor/system"
    )
    
    all_good=true
    for dir in "${sys_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            if [[ -w "$dir" ]] && ! is_running_as_sudo; then
                echo "  ✗ $dir is writable (should be protected)"
                all_good=false
            else
                echo "  ✓ $dir is properly protected"
            fi
        fi
    done
    
    if [[ "$all_good" == "true" ]]; then
        log_test_result "$test_name" "PASS"
    else
        log_test_result "$test_name" "FAIL" "System directories not properly protected"
    fi
}

# Test: Security phase awareness
test_security_phase() {
    echo
    echo "=== Testing Security Phase Awareness ==="
    
    local test_name="Get security phase"
    local phase=$(get_security_phase)
    
    if [[ -n "$phase" ]] && [[ "$phase" =~ ^(setup|hardened)$ ]]; then
        log_test_result "$test_name" "PASS"
        echo "  Current phase: $phase"
    else
        log_test_result "$test_name" "FAIL" "Invalid security phase: $phase"
    fi
    
    # Test phase permissions
    test_name="Phase permission checks"
    if [[ "$phase" == "setup" ]]; then
        # In setup phase, most operations should be allowed
        if is_operation_allowed "vm_create" && is_operation_allowed "system_config"; then
            log_test_result "$test_name" "PASS"
        else
            log_test_result "$test_name" "FAIL" "Setup phase too restrictive"
        fi
    else
        # In hardened phase, system operations should be restricted
        if is_operation_allowed "vm_start" && ! is_operation_allowed "system_config"; then
            log_test_result "$test_name" "PASS"
        else
            log_test_result "$test_name" "FAIL" "Hardened phase not properly restrictive"
        fi
    fi
}

# Summary report
print_summary() {
    echo
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Test Summary"
    echo "═══════════════════════════════════════════════════════════════"
    echo
    echo "  Total tests: $TESTS_RUN"
    echo -e "  Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "  Failed: ${RED}$TESTS_FAILED${NC}"
    echo
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "  ${GREEN}All tests passed!${NC}"
        echo
        return 0
    else
        echo -e "  ${RED}Some tests failed${NC}"
        echo
        echo "  Common fixes:"
        echo "  - Add user to libvirtd group: sudo usermod -aG libvirtd $USER"
        echo "  - Logout and login for group changes to take effect"
        echo "  - Check file permissions on VM directories"
        echo
        return 1
    fi
}

# Main test execution
main() {
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║           Privilege Separation Test Suite                     ║"
    echo "╠═══════════════════════════════════════════════════════════════╣"
    echo "║                                                               ║"
    echo "║  Testing privilege separation model for Hyper-NixOS           ║"
    echo "║  User: $TEST_USER                                             ║"
    echo "║  Running as sudo: $(is_running_as_sudo && echo "YES" || echo "NO")                                     ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo
    
    # Run tests
    test_libvirtd_group
    test_vm_operations_no_sudo
    test_script_privilege_checks
    test_privilege_functions
    test_file_permissions
    test_security_phase
    
    # Print summary
    print_summary
}

# Run tests
main "$@"