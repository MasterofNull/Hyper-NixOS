#!/usr/bin/env bash
#
# Hyper-NixOS Test Runner
# Runs all integration and unit tests

set -uo pipefail
# Note: NOT using -e because arithmetic operations can return non-zero

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Detect CI environment
CI_MODE=false
if [[ "${CI:-false}" == "true" ]] || [[ "${GITHUB_ACTIONS:-false}" == "true" ]]; then
  CI_MODE=true
fi

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║           Hyper-NixOS Test Suite                              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

if $CI_MODE; then
  echo -e "${BLUE}Running in CI mode${NC}"
  echo "Tests requiring libvirt/NixOS will be skipped"
  echo ""
fi

TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0
FAILED_TESTS=()

run_test() {
  local test_file="$1"
  local test_name=$(basename "$test_file" .sh)
  
  echo -n "Running: $test_name... "
  
  # In CI mode, check if test requires system features
  if $CI_MODE; then
    # Check if test requires libvirt/virtualization
    if grep -q "virsh\|libvirtd\|qemu-system" "$test_file" 2>/dev/null; then
      if ! command -v virsh &>/dev/null; then
        echo -e "${YELLOW}SKIP (requires libvirt)${NC}"
        TOTAL_SKIPPED=$((TOTAL_SKIPPED + 1))
        return 0
      fi
    fi
    
    # Check if test requires NixOS-specific features
    if grep -q "nixos-rebuild\|systemctl.*libvirtd" "$test_file" 2>/dev/null; then
      if ! command -v nixos-rebuild &>/dev/null; then
        echo -e "${YELLOW}SKIP (requires NixOS)${NC}"
        TOTAL_SKIPPED=$((TOTAL_SKIPPED + 1))
        return 0
      fi
    fi
  fi
  
  if bash "$test_file" >/dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
    TOTAL_PASSED=$((TOTAL_PASSED + 1))
  else
    echo -e "${RED}FAIL${NC}"
    TOTAL_FAILED=$((TOTAL_FAILED + 1))
    FAILED_TESTS+=("$test_name")
  fi
}

# Run integration tests
if [[ -d integration ]]; then
  echo "═══ Integration Tests ═══"
  for test in integration/test_*.sh; do
    [[ -f "$test" ]] && run_test "$test"
  done
  echo ""
fi

# Run unit tests
if [[ -d unit ]] && ls unit/test_*.sh >/dev/null 2>&1; then
  echo "═══ Unit Tests ═══"
  for test in unit/test_*.sh; do
    [[ -f "$test" ]] && run_test "$test"
  done
  echo ""
fi

# Summary
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║           TEST SUMMARY                                        ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo -e "Passed:  ${GREEN}$TOTAL_PASSED${NC}"
echo -e "Failed:  ${RED}$TOTAL_FAILED${NC}"
echo -e "Skipped: ${YELLOW}$TOTAL_SKIPPED${NC}"
echo ""

# CI mode: Skipped tests are OK
if $CI_MODE; then
  if [[ $TOTAL_FAILED -gt 0 ]]; then
    echo "Failed Tests:"
    for test in "${FAILED_TESTS[@]}"; do
      echo "  - $test"
    done
    echo ""
    echo "✗ Some CI validation checks failed"
    exit 1
  fi
  
  if [[ $TOTAL_SKIPPED -gt 0 ]]; then
    echo -e "${BLUE}Tests requiring NixOS/libvirt were skipped (expected in CI)${NC}"
    echo "Full integration tests run when deployed on actual NixOS system"
  fi
  
  echo ""
  echo "✓ CI validation successful!"
  exit 0
fi

# Non-CI mode
if [[ $TOTAL_FAILED -gt 0 ]]; then
  echo "Failed Tests:"
  for test in "${FAILED_TESTS[@]}"; do
    echo "  - $test"
  done
  echo ""
  exit 1
fi

echo "✓ All tests passed!"
exit 0
