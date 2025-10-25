#!/bin/bash
set -euo pipefail

# Comprehensive test runner for Hyper-NixOS
# This script orchestrates all test suites and calculates test coverage

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🧪 Hyper-NixOS Comprehensive Test Suite${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_RESULTS_DIR="$SCRIPT_DIR/results"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

mkdir -p "$TEST_RESULTS_DIR"

# Track test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Calculate test coverage
TOTAL_MODULES=$(find "$PROJECT_ROOT/modules" -name "*.nix" -type f | wc -l)
TOTAL_SCRIPTS=$(find "$PROJECT_ROOT/scripts" -name "*.sh" -type f | wc -l)
TESTED_MODULES=$(find "$SCRIPT_DIR/modules" -name "test_*.nix" -type f | grep -v template | wc -l)
TESTED_SCRIPTS=$(find "$SCRIPT_DIR/scripts" -name "test_*.bats" -type f | grep -v template | wc -l)

MODULE_COVERAGE=$((TESTED_MODULES * 100 / TOTAL_MODULES))
SCRIPT_COVERAGE=$((TESTED_SCRIPTS * 100 / TOTAL_SCRIPTS))
OVERALL_COVERAGE=$(( (TESTED_MODULES + TESTED_SCRIPTS) * 100 / (TOTAL_MODULES + TOTAL_SCRIPTS) ))

# Check if running on NixOS
is_nixos() {
  [ -f /etc/NIXOS ] || [ -f /run/current-system/nixos-version ]
}

# Check if libvirt is available
has_libvirt() {
  command -v virsh >/dev/null 2>&1
}

# Check if BATS is available
has_bats() {
  command -v bats >/dev/null 2>&1
}

echo "🔍 Environment Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if is_nixos; then
  echo -e "  ${GREEN}✓${NC} Running on NixOS"
else
  echo -e "  ${YELLOW}⚠${NC} Not running on NixOS (some tests will be skipped)"
fi

if has_libvirt; then
  echo -e "  ${GREEN}✓${NC} Libvirt available"
else
  echo -e "  ${YELLOW}⚠${NC} Libvirt not available (virtualization tests will be skipped)"
fi

if has_bats; then
  echo -e "  ${GREEN}✓${NC} BATS testing framework available"
else
  echo -e "  ${YELLOW}⚠${NC} BATS not available (install with: nix-shell -p bats)"
  echo -e "  ${YELLOW}⚠${NC} Script tests will be skipped"
fi

echo ""

# ============================================================================
# MODULE TESTS
# ============================================================================

echo -e "${BLUE}📦 Testing NixOS Modules${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if is_nixos; then
  MODULE_TEST_COUNT=0
  MODULE_PASS_COUNT=0

  for test in "$SCRIPT_DIR"/modules/test_*.nix; do
    [ -f "$test" ] || continue

    test_name=$(basename "$test" .nix)
    echo -n "  Testing ${test_name}... "

    ((MODULE_TEST_COUNT++))
    ((TOTAL_TESTS++))

    if nix-build "$test" -o "$TEST_RESULTS_DIR/${test_name}-result" 2>&1 | tee "$TEST_RESULTS_DIR/${test_name}.log" >/dev/null; then
      echo -e "${GREEN}PASS${NC}"
      ((MODULE_PASS_COUNT++))
      ((PASSED_TESTS++))
    else
      echo -e "${RED}FAIL${NC}"
      ((FAILED_TESTS++))
      echo "    See: $TEST_RESULTS_DIR/${test_name}.log"
    fi
  done

  echo ""
  echo "  Module Tests: $MODULE_PASS_COUNT/$MODULE_TEST_COUNT passed"
else
  echo -e "  ${YELLOW}⊘${NC} Skipped (requires NixOS)"
  for test in "$SCRIPT_DIR"/modules/test_*.nix; do
    [ -f "$test" ] || continue
    ((TOTAL_TESTS++))
    ((SKIPPED_TESTS++))
  done
fi

echo ""

# ============================================================================
# SCRIPT TESTS
# ============================================================================

echo -e "${BLUE}📜 Testing Shell Scripts${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if has_bats; then
  SCRIPT_TEST_COUNT=0
  SCRIPT_PASS_COUNT=0

  for test in "$SCRIPT_DIR"/scripts/test_*.bats; do
    [ -f "$test" ] || continue

    test_name=$(basename "$test" .bats)
    echo "  Running ${test_name}..."

    ((SCRIPT_TEST_COUNT++))

    if bats "$test" 2>&1 | tee "$TEST_RESULTS_DIR/${test_name}.log"; then
      ((SCRIPT_PASS_COUNT++))
      # Count individual BATS tests
      local bats_count=$(grep -c "^ok" "$TEST_RESULTS_DIR/${test_name}.log" || echo 0)
      ((TOTAL_TESTS += bats_count))
      ((PASSED_TESTS += bats_count))
    else
      # Count failures
      local bats_passed=$(grep -c "^ok" "$TEST_RESULTS_DIR/${test_name}.log" || echo 0)
      local bats_failed=$(grep -c "^not ok" "$TEST_RESULTS_DIR/${test_name}.log" || echo 0)
      ((TOTAL_TESTS += bats_passed + bats_failed))
      ((PASSED_TESTS += bats_passed))
      ((FAILED_TESTS += bats_failed))
    fi
  done

  echo ""
  echo "  Script Test Files: $SCRIPT_PASS_COUNT/$SCRIPT_TEST_COUNT passed"
else
  echo -e "  ${YELLOW}⊘${NC} Skipped (BATS not available)"
  for test in "$SCRIPT_DIR"/scripts/test_*.bats; do
    [ -f "$test" ] || continue
    ((SKIPPED_TESTS++))
  done
fi

echo ""

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

echo -e "${BLUE}🔗 Running Integration Tests${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -d "$SCRIPT_DIR/integration" ]; then
  if [ -f "$SCRIPT_DIR/integration/run_all.sh" ]; then
    if bash "$SCRIPT_DIR/integration/run_all.sh" 2>&1 | tee "$TEST_RESULTS_DIR/integration.log"; then
      echo -e "  ${GREEN}✓${NC} Integration tests passed"
      # Parse integration test results if available
    else
      echo -e "  ${RED}✗${NC} Integration tests failed"
    fi
  else
    echo -e "  ${YELLOW}⊘${NC} No integration test runner found"
  fi
else
  echo -e "  ${YELLOW}⊘${NC} No integration tests directory"
fi

echo ""

# ============================================================================
# SECURITY TESTS
# ============================================================================

echo -e "${BLUE}🔒 Running Security Tests${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "$SCRIPT_DIR/integration-test-security.sh" ]; then
  if bash "$SCRIPT_DIR/integration-test-security.sh" 2>&1 | tee "$TEST_RESULTS_DIR/security.log"; then
    echo -e "  ${GREEN}✓${NC} Security tests passed"
  else
    echo -e "  ${RED}✗${NC} Security tests failed"
  fi
else
  echo -e "  ${YELLOW}⊘${NC} No security test suite found"
fi

echo ""

# ============================================================================
# STATIC ANALYSIS
# ============================================================================

echo -e "${BLUE}🔍 Running Static Analysis${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check shell scripts with shellcheck if available
if command -v shellcheck >/dev/null 2>&1; then
  echo "  Running shellcheck on scripts..."
  SHELLCHECK_ERRORS=0

  while IFS= read -r -d '' script; do
    if ! shellcheck "$script" >/dev/null 2>&1; then
      ((SHELLCHECK_ERRORS++))
    fi
  done < <(find "$PROJECT_ROOT/scripts" -type f -name "*.sh" -print0 2>/dev/null)

  if [ $SHELLCHECK_ERRORS -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} All scripts pass shellcheck"
  else
    echo -e "  ${YELLOW}⚠${NC} $SHELLCHECK_ERRORS scripts have shellcheck warnings"
  fi
else
  echo -e "  ${YELLOW}⊘${NC} shellcheck not available"
fi

# Check Nix syntax
echo "  Checking Nix file syntax..."
NIX_ERRORS=0

while IFS= read -r -d '' nixfile; do
  if ! nix-instantiate --parse "$nixfile" >/dev/null 2>&1; then
    ((NIX_ERRORS++))
    echo -e "  ${RED}✗${NC} Syntax error in $nixfile"
  fi
done < <(find "$PROJECT_ROOT/modules" "$PROJECT_ROOT" -maxdepth 1 -type f -name "*.nix" -print0 2>/dev/null)

if [ $NIX_ERRORS -eq 0 ]; then
  echo -e "  ${GREEN}✓${NC} All Nix files have valid syntax"
else
  echo -e "  ${RED}✗${NC} $NIX_ERRORS Nix files have syntax errors"
fi

echo ""

# ============================================================================
# SUMMARY
# ============================================================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📊 Test Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Total tests:   $TOTAL_TESTS"
echo -e "  ${GREEN}Passed:        $PASSED_TESTS${NC}"

if [ $FAILED_TESTS -gt 0 ]; then
  echo -e "  ${RED}Failed:        $FAILED_TESTS${NC}"
fi

if [ $SKIPPED_TESTS -gt 0 ]; then
  echo -e "  ${YELLOW}Skipped:       $SKIPPED_TESTS${NC}"
fi

echo ""
echo "  Results saved to: $TEST_RESULTS_DIR"
echo ""

# ============================================================================
# TEST COVERAGE REPORT
# ============================================================================

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}📈 Test Coverage Report${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Module coverage
echo -e "${MAGENTA}Modules:${NC}"
echo "  Total modules:  $TOTAL_MODULES"
echo "  Tested modules: $TESTED_MODULES"
echo -n "  Coverage:       "

if [ $MODULE_COVERAGE -ge 80 ]; then
  echo -e "${GREEN}${MODULE_COVERAGE}%${NC} ✓ Target reached!"
elif [ $MODULE_COVERAGE -ge 50 ]; then
  echo -e "${YELLOW}${MODULE_COVERAGE}%${NC} (target: 80%)"
else
  echo -e "${RED}${MODULE_COVERAGE}%${NC} (target: 80%)"
fi

echo ""

# Script coverage
echo -e "${MAGENTA}Scripts:${NC}"
echo "  Total scripts:  $TOTAL_SCRIPTS"
echo "  Tested scripts: $TESTED_SCRIPTS"
echo -n "  Coverage:       "

if [ $SCRIPT_COVERAGE -ge 80 ]; then
  echo -e "${GREEN}${SCRIPT_COVERAGE}%${NC} ✓ Target reached!"
elif [ $SCRIPT_COVERAGE -ge 50 ]; then
  echo -e "${YELLOW}${SCRIPT_COVERAGE}%${NC} (target: 80%)"
else
  echo -e "${RED}${SCRIPT_COVERAGE}%${NC} (target: 80%)"
fi

echo ""

# Overall coverage
echo -e "${MAGENTA}Overall:${NC}"
TOTAL_ITEMS=$((TOTAL_MODULES + TOTAL_SCRIPTS))
TESTED_ITEMS=$((TESTED_MODULES + TESTED_SCRIPTS))
echo "  Total items:    $TOTAL_ITEMS"
echo "  Tested items:   $TESTED_ITEMS"
echo -n "  Coverage:       "

if [ $OVERALL_COVERAGE -ge 80 ]; then
  echo -e "${GREEN}${OVERALL_COVERAGE}%${NC} ✓ CRITICAL REQUIREMENT MET!"
elif [ $OVERALL_COVERAGE -ge 50 ]; then
  echo -e "${YELLOW}${OVERALL_COVERAGE}%${NC} (CRITICAL: 80% required for deployment)"
else
  echo -e "${RED}${OVERALL_COVERAGE}%${NC} (CRITICAL: 80% required for deployment)"
fi

echo ""

# Gap analysis
if [ $OVERALL_COVERAGE -lt 80 ]; then
  COVERAGE_GAP=$((80 - OVERALL_COVERAGE))
  TESTS_NEEDED=$(( (TOTAL_ITEMS * 80 / 100) - TESTED_ITEMS ))

  echo -e "${YELLOW}Gap to target:${NC}"
  echo -e "  Missing coverage: ${COVERAGE_GAP}%"
  echo -e "  Tests needed:     ~${TESTS_NEEDED} more tests"
  echo ""
fi

# Save coverage report
cat > "$TEST_RESULTS_DIR/coverage-${TIMESTAMP}.txt" <<EOF
Hyper-NixOS Test Coverage Report
Generated: $(date)

Module Coverage:    ${MODULE_COVERAGE}% ($TESTED_MODULES/$TOTAL_MODULES)
Script Coverage:    ${SCRIPT_COVERAGE}% ($TESTED_SCRIPTS/$TOTAL_SCRIPTS)
Overall Coverage:   ${OVERALL_COVERAGE}% ($TESTED_ITEMS/$TOTAL_ITEMS)

Target: 80% (CRITICAL REQUIREMENT #7)
Status: $([ $OVERALL_COVERAGE -ge 80 ] && echo "MET" || echo "NOT MET - $((80 - OVERALL_COVERAGE))% gap")
EOF

echo -e "  ${BLUE}Coverage report saved to:${NC} $TEST_RESULTS_DIR/coverage-${TIMESTAMP}.txt"
echo ""

# Exit with appropriate code
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ $FAILED_TESTS -gt 0 ]; then
  echo -e "${RED}❌ Some tests failed${NC}"
  exit 1
elif [ $OVERALL_COVERAGE -lt 80 ]; then
  echo -e "${YELLOW}⚠  Tests passed but coverage below 80% requirement${NC}"
  echo -e "${YELLOW}   Deployment blocked until coverage target is met${NC}"
  exit 2
else
  echo -e "${GREEN}✅ All tests passed! Coverage target met!${NC}"
  exit 0
fi
