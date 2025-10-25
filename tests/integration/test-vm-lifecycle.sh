#!/usr/bin/env bash
# Integration test for VM lifecycle
set -euo pipefail

echo "========================================="
echo "VM Lifecycle Integration Test"
echo "========================================="
echo ""

# Test configuration
TEST_VM_NAME="integration-test-vm-$$"
TEST_PROFILE="/tmp/${TEST_VM_NAME}.json"
TEST_DISK="/tmp/${TEST_VM_NAME}.qcow2"

# Cleanup function
cleanup() {
  echo ""
  echo "Cleaning up..."
  virsh destroy "$TEST_VM_NAME" 2>/dev/null || true
  virsh undefine "$TEST_VM_NAME" --remove-all-storage 2>/dev/null || true
  rm -f "$TEST_PROFILE" "$TEST_DISK"
  echo "Cleanup complete"
}

trap cleanup EXIT

# Test 1: Create VM profile
echo "Test 1: Creating VM profile..."
cat > "$TEST_PROFILE" <<EOF
{
  "name": "$TEST_VM_NAME",
  "cpus": 1,
  "memory_mb": 512,
  "disk_gb": 1,
  "arch": "x86_64"
}
EOF

if [[ -f "$TEST_PROFILE" ]]; then
  echo "  ✓ Profile created successfully"
else
  echo "  ✗ Failed to create profile"
  exit 1
fi

# Test 2: Validate JSON
echo ""
echo "Test 2: Validating JSON..."
if jq '.' "$TEST_PROFILE" >/dev/null 2>&1; then
  echo "  ✓ JSON is valid"
else
  echo "  ✗ JSON is invalid"
  exit 1
fi

# Test 3: Create disk image
echo ""
echo "Test 3: Creating disk image..."
if qemu-img create -f qcow2 "$TEST_DISK" 1G >/dev/null 2>&1; then
  echo "  ✓ Disk image created"
else
  echo "  ✗ Failed to create disk image"
  exit 1
fi

# Test 4: Check disk size
echo ""
echo "Test 4: Verifying disk image..."
disk_info=$(qemu-img info "$TEST_DISK" 2>/dev/null)
if echo "$disk_info" | grep -q "qcow2"; then
  echo "  ✓ Disk image format correct (qcow2)"
else
  echo "  ✗ Disk image format incorrect"
  exit 1
fi

# Test 5: Libvirt connectivity
echo ""
echo "Test 5: Testing libvirt connectivity..."
if virsh version >/dev/null 2>&1; then
  echo "  ✓ Can connect to libvirt"
else
  echo "  ✗ Cannot connect to libvirt"
  exit 1
fi

# Test 6: Default network exists
echo ""
echo "Test 6: Checking default network..."
if virsh net-info default >/dev/null 2>&1; then
  echo "  ✓ Default network exists"
  
  # Start if not active
  if ! virsh net-info default | grep -q "Active:.*yes"; then
    echo "  Starting default network..."
    virsh net-start default 2>/dev/null || true
  fi
else
  echo "  ⚠ Default network not found (may not be needed)"
fi

echo ""
echo "========================================="
echo "All tests passed! ✓"
echo "========================================="
