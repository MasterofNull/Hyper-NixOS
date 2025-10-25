#!/usr/bin/env bash
# Test encryption support functionality
# This script tests the encryption detection and preservation logic

set -eo pipefail  # Don't use -u to allow unset variables in tests

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Source the encryption support library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/lib/encryption-support.sh"

# Test framework functions
test_start() {
  TESTS_RUN=$((TESTS_RUN + 1))
  printf "Testing: %s ... " "$1"
}

test_pass() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo -e "${GREEN}PASS${NC}"
}

test_fail() {
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo -e "${RED}FAIL${NC}"
  echo "  Reason: $1"
}

# Create temporary test directory
TEST_DIR=$(mktemp -d -t encryption-test.XXXXXX)
cleanup_test_dir() {
  local exit_code=$?
  [[ -d "$TEST_DIR" ]] && rm -rf "$TEST_DIR"
  exit $exit_code
}
trap cleanup_test_dir EXIT INT TERM

# Test 1: Extract LUKS config from sample hardware-configuration.nix
test_luks_extraction() {
  test_start "LUKS configuration extraction"
  
  # Create sample hardware config with LUKS
  cat > "$TEST_DIR/hw-config-with-luks.nix" <<'EOF'
{ config, lib, pkgs, ... }:
{
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "dm_mod" "dm_crypt" ];
  
  boot.initrd.luks.devices = {
    root = {
      device = "/dev/nvme0n1p2";
      preLVM = true;
      allowDiscards = true;
    };
  };
  
  fileSystems."/" = {
    device = "/dev/mapper/root";
    fsType = "ext4";
  };
}
EOF
  
  # Extract LUKS config
  local luks_config
  luks_config=$(extract_luks_config "$TEST_DIR/hw-config-with-luks.nix")
  
  # Verify extraction
  if echo "$luks_config" | grep -q "boot\.initrd\.luks\.devices"; then
    if echo "$luks_config" | grep -q "/dev/nvme0n1p2"; then
      test_pass
      return 0
    fi
  fi
  
  test_fail "LUKS config not extracted correctly"
  return 1
}

# Test 2: Extract LUKS config from file without encryption
test_no_luks_extraction() {
  test_start "Non-encrypted config handling"
  
  # Create sample hardware config without LUKS
  cat > "$TEST_DIR/hw-config-plain.nix" <<'EOF'
{ config, lib, pkgs, ... }:
{
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" ];
  
  fileSystems."/" = {
    device = "/dev/nvme0n1p1";
    fsType = "ext4";
  };
}
EOF
  
  # Extract LUKS config (should be empty)
  local luks_config
  luks_config=$(extract_luks_config "$TEST_DIR/hw-config-plain.nix")
  
  # Verify no LUKS config extracted
  if [[ -z "$luks_config" ]]; then
    test_pass
    return 0
  fi
  
  test_fail "Extracted LUKS config from non-encrypted file"
  return 1
}

# Test 3: Validate encryption config
test_validate_encryption() {
  test_start "Encryption configuration validation"
  
  # Use the LUKS config from test 1
  if validate_encryption_config "$TEST_DIR/hw-config-with-luks.nix" 2>/dev/null; then
    test_pass
    return 0
  fi
  
  test_fail "Encryption validation failed for valid config"
  return 1
}

# Test 4: Validate non-encrypted config should fail
test_validate_no_encryption() {
  test_start "Non-encrypted config validation (should fail)"
  
  if validate_encryption_config "$TEST_DIR/hw-config-plain.nix" 2>/dev/null; then
    test_fail "Validation passed for non-encrypted config"
    return 1
  fi
  
  test_pass
  return 0
}

# Test 5: Merge LUKS config into plain config
test_merge_luks() {
  test_start "LUKS configuration merge"
  
  # Create target config without LUKS
  cp "$TEST_DIR/hw-config-plain.nix" "$TEST_DIR/hw-config-merge-target.nix"
  
  # Extract LUKS config from encrypted version
  local luks_config
  luks_config=$(extract_luks_config "$TEST_DIR/hw-config-with-luks.nix")
  
  # Merge LUKS config
  if merge_luks_config "$TEST_DIR/hw-config-merge-target.nix" "$luks_config" 2>/dev/null; then
    # Verify merge
    if grep -q "boot\.initrd\.luks\.devices" "$TEST_DIR/hw-config-merge-target.nix"; then
      test_pass
      return 0
    fi
  fi
  
  test_fail "LUKS config merge failed"
  return 1
}

# Test 6: Complex LUKS config with multiple devices
test_complex_luks() {
  test_start "Complex LUKS configuration (multiple devices)"
  
  # Create complex hardware config
  cat > "$TEST_DIR/hw-config-complex.nix" <<'EOF'
{ config, lib, pkgs, ... }:
{
  boot.initrd.availableKernelModules = [ "dm_mod" "dm_crypt" "aes_x86_64" ];
  
  boot.initrd.luks.devices = {
    root = {
      device = "/dev/nvme0n1p2";
      preLVM = true;
      allowDiscards = true;
      keyFile = "/crypto_keyfile.bin";
    };
    home = {
      device = "/dev/nvme0n1p3";
      keyFile = "/crypto_keyfile.bin";
    };
  };
  
  fileSystems."/" = {
    device = "/dev/mapper/root";
    fsType = "ext4";
  };
  
  fileSystems."/home" = {
    device = "/dev/mapper/home";
    fsType = "ext4";
  };
}
EOF
  
  # Extract and validate
  local luks_config
  luks_config=$(extract_luks_config "$TEST_DIR/hw-config-complex.nix")
  
  if echo "$luks_config" | grep -q "root ="; then
    if echo "$luks_config" | grep -q "home ="; then
      if echo "$luks_config" | grep -q "keyFile"; then
        test_pass
        return 0
      fi
    fi
  fi
  
  test_fail "Complex LUKS config not extracted correctly"
  return 1
}

# Test 7: Preserve initrd settings
test_initrd_preservation() {
  test_start "Initrd settings preservation"
  
  # Extract all initrd settings
  local initrd_config
  initrd_config=$(extract_initrd_config "$TEST_DIR/hw-config-with-luks.nix")
  
  if echo "$initrd_config" | grep -q "boot\.initrd"; then
    if echo "$initrd_config" | grep -q "dm_mod"; then
      if echo "$initrd_config" | grep -q "dm_crypt"; then
        test_pass
        return 0
      fi
    fi
  fi
  
  test_fail "Initrd settings not preserved correctly"
  return 1
}

# Run all tests
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Encryption Support Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

test_luks_extraction
test_no_luks_extraction
test_validate_encryption
test_validate_no_encryption
test_merge_luks
test_complex_luks
test_initrd_preservation

# Summary
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Tests run: $TESTS_RUN"
echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
  echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 1
else
  echo "  Failed: 0"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${GREEN}✓ All tests passed!${NC}"
  exit 0
fi
