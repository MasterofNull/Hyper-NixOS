#!/usr/bin/env bash
#
# Test Helper Functions
# Common utilities for test scripts
#

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TEST_TOTAL=0
TEST_PASSED=0
TEST_FAILED=0
TEST_WARNED=0

# Test suite info
SUITE_NAME=""
SUITE_START_TIME=0

test_suite_start() {
  SUITE_NAME="$1"
  SUITE_START_TIME=$(date +%s)
  
  echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║${NC}  TEST SUITE: $SUITE_NAME"
  echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

test_suite_end() {
  local end_time=$(date +%s)
  local duration=$((end_time - SUITE_START_TIME))
  
  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  RESULTS${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "  Total:   $TEST_TOTAL"
  echo -e "  ${GREEN}Passed:  $TEST_PASSED${NC}"
  echo -e "  ${RED}Failed:  $TEST_FAILED${NC}"
  echo -e "  ${YELLOW}Warned:  $TEST_WARNED${NC}"
  echo -e "  Duration: ${duration}s"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
  
  if [[ $TEST_FAILED -gt 0 ]]; then
    exit 1
  fi
}

test_start() {
  local name="$1"
  echo -n "  Testing: $name ... "
  TEST_TOTAL=$((TEST_TOTAL + 1))
}

# Alias for consistency
test_case() {
  test_start "$@"
}

test_pass() {
  local message="${1:-}"
  TEST_PASSED=$((TEST_PASSED + 1))
  
  if [[ -n "$message" ]]; then
    echo -e "${GREEN}✓${NC} $message"
  else
    echo -e "${GREEN}✓ PASS${NC}"
  fi
}

test_fail() {
  local message="${1:-}"
  TEST_FAILED=$((TEST_FAILED + 1))
  
  if [[ -n "$message" ]]; then
    echo -e "${RED}✗${NC} $message"
  else
    echo -e "${RED}✗ FAIL${NC}"
  fi
}

test_warn() {
  local message="${1:-}"
  ((TEST_WARNED++))
  
  if [[ -n "$message" ]]; then
    echo -e "${YELLOW}⚠${NC} $message"
  else
    echo -e "${YELLOW}⚠ WARNING${NC}"
  fi
}

# Assertion helpers
assert_file_exists() {
  local file="$1"
  if [[ -f "$file" ]]; then
    return 0
  else
    return 1
  fi
}

assert_dir_exists() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    return 0
  else
    return 1
  fi
}

assert_command_exists() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

assert_service_active() {
  local service="$1"
  if systemctl is-active "$service" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

assert_string_contains() {
  local string="$1"
  local substring="$2"
  if echo "$string" | grep -q "$substring"; then
    return 0
  else
    return 1
  fi
}

assert_equals() {
  local expected="$1"
  local actual="$2"
  if [[ "$expected" == "$actual" ]]; then
    return 0
  else
    echo "  Expected: $expected"
    echo "  Actual:   $actual"
    return 1
  fi
}
