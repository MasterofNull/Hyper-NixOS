#!/usr/bin/env bash
#
# Run All Tests
# Executes all integration and unit tests
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║           Hyper-NixOS Test Suite                              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

TOTAL_PASSED=0
TOTAL_FAILED=0
FAILED_TESTS=()

run_test() {
  local test_file="$1"
  local test_name=$(basename "$test_file" .sh)
  
  echo "Running: $test_name"
  
  if bash "$test_file"; then
    ((TOTAL_PASSED++))
  else
    ((TOTAL_FAILED++))
    FAILED_TESTS+=("$test_name")
  fi
  
  echo ""
}

# Run integration tests
echo "═══ Integration Tests ═══"
for test in integration/test_*.sh; do
  [[ -f "$test" ]] && run_test "$test"
done

# Run unit tests
if [[ -d unit ]] && ls unit/test_*.sh >/dev/null 2>&1; then
  echo "═══ Unit Tests ═══"
  for test in unit/test_*.sh; do
    [[ -f "$test" ]] && run_test "$test"
  done
fi

# Summary
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║           TEST SUMMARY                                        ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Total Passed: $TOTAL_PASSED"
echo "Total Failed: $TOTAL_FAILED"

if [[ $TOTAL_FAILED -gt 0 ]]; then
  echo ""
  echo "Failed Tests:"
  for test in "${FAILED_TESTS[@]}"; do
    echo "  - $test"
  done
  echo ""
  exit 1
else
  echo ""
  echo "✓ All tests passed!"
  exit 0
fi
