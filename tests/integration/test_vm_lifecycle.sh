#!/usr/bin/env bash
#
# Integration Test: VM Lifecycle
# Tests VM creation, start, stop, deletion
#

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TEST_DIR/lib/test_helpers.sh"

VM_NAME="test-vm-$$"
VM_PROFILE="/tmp/test-vm-$$.json"

cleanup() {
  # Clean up test VM
  virsh destroy "$VM_NAME" 2>/dev/null || true
  virsh undefine "$VM_NAME" 2>/dev/null || true
  rm -f "$VM_PROFILE"
}
trap cleanup EXIT

test_vm_profile_creation() {
  test_start "Create VM profile"
  
  cat > "$VM_PROFILE" << EOF
{
  "name": "$VM_NAME",
  "memory_mb": 1024,
  "cpus": 1,
  "disk_gb": 10,
  "iso_path": "/dev/null",
  "network": "default"
}
EOF
  
  if [[ -f "$VM_PROFILE" ]]; then
    test_pass "VM profile created"
  else
    test_fail "Failed to create VM profile"
  fi
}

test_vm_creation() {
  test_start "Create VM from profile"
  
  if /etc/hypervisor/scripts/json_to_libvirt_xml_and_define.sh "$VM_PROFILE" >/dev/null 2>&1; then
    test_pass "VM created successfully"
  else
    test_fail "VM creation failed"
  fi
}

test_vm_appears_in_list() {
  test_start "VM appears in virsh list"
  
  if virsh list --all | grep -q "$VM_NAME"; then
    test_pass "VM found in list"
  else
    test_fail "VM not found in list"
  fi
}

test_vm_start() {
  test_start "Start VM"
  
  if virsh start "$VM_NAME" >/dev/null 2>&1; then
    sleep 2
    if virsh list --state-running | grep -q "$VM_NAME"; then
      test_pass "VM started successfully"
    else
      test_fail "VM not running after start"
    fi
  else
    test_fail "Failed to start VM"
  fi
}

test_vm_stop() {
  test_start "Stop VM"
  
  if virsh shutdown "$VM_NAME" >/dev/null 2>&1; then
    sleep 2
    if ! virsh list --state-running | grep -q "$VM_NAME"; then
      test_pass "VM stopped successfully"
    else
      test_fail "VM still running after stop"
    fi
  else
    test_fail "Failed to stop VM"
  fi
}

test_vm_deletion() {
  test_start "Delete VM"
  
  if virsh undefine "$VM_NAME" >/dev/null 2>&1; then
    if ! virsh list --all | grep -q "$VM_NAME"; then
      test_pass "VM deleted successfully"
    else
      test_fail "VM still exists after deletion"
    fi
  else
    test_fail "Failed to delete VM"
  fi
}

# Run tests
main() {
  test_suite_start "VM Lifecycle"
  
  test_vm_profile_creation
  test_vm_creation
  test_vm_appears_in_list
  test_vm_start
  test_vm_stop
  test_vm_deletion
  
  test_suite_end
}

main "$@"
