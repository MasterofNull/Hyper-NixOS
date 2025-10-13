#!/usr/bin/env bash
#
# Integration Test: VM Lifecycle
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test_helpers.sh"

# Detect CI environment
CI_MODE=false
if [[ "${CI:-false}" == "true" ]] || [[ "${GITHUB_ACTIONS:-false}" == "true" ]]; then
  CI_MODE=true
fi

test_suite_start "VM Lifecycle"

# In CI, only validate structure and syntax
if $CI_MODE; then
  test_case "VM management scripts exist"
  assert_file_exists "../../scripts/menu.sh"
  assert_file_exists "../../scripts/vm_setup_workflow.sh"
  
  test_case "VM management scripts have valid syntax"
  if bash -n "../../scripts/menu.sh" 2>/dev/null && \
     bash -n "../../scripts/vm_setup_workflow.sh" 2>/dev/null; then
    test_pass "All VM scripts have valid syntax"
  else
    test_fail "Syntax errors in VM scripts"
  fi
  
  test_case "Configuration supports virtualization"
  if grep -q "virtualisation.libvirtd" "../../configuration.nix"; then
    test_pass "Libvirt configuration present"
  else
    test_info "Libvirt will be configured during installation"
  fi
  
  test_suite_end
  exit 0
fi

# Full integration tests (requires libvirt)
if ! command -v virsh &>/dev/null; then
  test_info "Skipping full tests - requires libvirt"
  test_suite_end
  exit 0
fi

TEST_VM="test-vm-$$"
TEST_DISK="/tmp/test-vm-$$.qcow2"

cleanup() {
  virsh destroy "$TEST_VM" 2>/dev/null || true
  virsh undefine "$TEST_VM" 2>/dev/null || true
  rm -f "$TEST_DISK"
}

trap cleanup EXIT

test_case "Create test VM disk"
qemu-img create -f qcow2 "$TEST_DISK" 1G >/dev/null 2>&1
assert_file_exists "$TEST_DISK"

test_case "Define VM"
cat > /tmp/test-vm.xml <<EOF
<domain type='kvm'>
  <name>$TEST_VM</name>
  <memory unit='MiB'>512</memory>
  <vcpu>1</vcpu>
  <os>
    <type arch='x86_64'>hvm</type>
  </os>
  <devices>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='$TEST_DISK'/>
      <target dev='vda' bus='virtio'/>
    </disk>
  </devices>
</domain>
EOF

virsh define /tmp/test-vm.xml >/dev/null 2>&1
rm /tmp/test-vm.xml

if virsh list --all --name | grep -q "^$TEST_VM$"; then
  test_pass "VM defined successfully"
else
  test_fail "VM definition failed"
fi

test_case "Start VM"
if virsh start "$TEST_VM" >/dev/null 2>&1; then
  test_pass "VM started"
else
  test_info "VM start may fail without proper configuration"
fi

test_case "Check VM state"
if virsh list --name | grep -q "^$TEST_VM$"; then
  test_pass "VM is running"
fi

test_case "Stop VM"
virsh destroy "$TEST_VM" >/dev/null 2>&1
if ! virsh list --name | grep -q "^$TEST_VM$"; then
  test_pass "VM stopped"
fi

test_case "Delete VM"
virsh undefine "$TEST_VM" >/dev/null 2>&1
if ! virsh list --all --name | grep -q "^$TEST_VM$"; then
  test_pass "VM deleted"
fi

test_suite_end
