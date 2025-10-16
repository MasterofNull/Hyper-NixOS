#!/usr/bin/env bash
# Test script for installer non-interactive mode
# Tests the fix for the infinite loop bug

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_LOG="/tmp/installer_test_$(date +%s).log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_test() { echo -e "${BLUE}[TEST]${NC} $*"; }
print_pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
print_fail() { echo -e "${RED}[FAIL]${NC} $*"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

test_count=0
pass_count=0
fail_count=0

run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local expected_exit="${3:-0}"
    
    test_count=$((test_count + 1))
    print_test "Running: $test_name"
    
    local start_time=$(date +%s)
    local timeout=10  # 10 second timeout for tests
    
    # Run with timeout
    if timeout $timeout bash -c "$test_cmd" &> "$TEST_LOG"; then
        local actual_exit=0
    else
        local actual_exit=$?
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Check if it completed in reasonable time
    if [[ $duration -ge $timeout ]]; then
        print_fail "$test_name - Timeout (${duration}s)"
        fail_count=$((fail_count + 1))
        return 1
    fi
    
    if [[ $actual_exit -eq $expected_exit ]]; then
        print_pass "$test_name - Completed in ${duration}s"
        pass_count=$((pass_count + 1))
        return 0
    else
        print_fail "$test_name - Exit code $actual_exit (expected $expected_exit)"
        fail_count=$((fail_count + 1))
        echo "Last 10 lines of output:"
        tail -n 10 "$TEST_LOG"
        return 1
    fi
}

echo "========================================"
echo "Installer Non-Interactive Mode Tests"
echo "========================================"
echo

# Test 1: Syntax check
print_test "Test 1: Syntax validation"
if bash -n "$SCRIPT_DIR/../install.sh"; then
    print_pass "Syntax check passed"
    pass_count=$((pass_count + 1))
else
    print_fail "Syntax check failed"
    fail_count=$((fail_count + 1))
fi
test_count=$((test_count + 1))

# Test 2: Closed stdin (simulates piped from curl with no input)
echo
run_test "Test 2: Closed stdin detection" \
    "bash -c 'source $SCRIPT_DIR/../install.sh; prompt_download_method' < /dev/null" \
    0

# Test 3: Empty input stream
echo
run_test "Test 3: Empty input stream (EOF immediately)" \
    "echo '' | bash -c 'source $SCRIPT_DIR/../install.sh; prompt_download_method'" \
    0

# Test 4: Invalid input followed by valid
echo
run_test "Test 4: Invalid then valid input" \
    "echo -e 'invalid\n1' | bash -c 'source $SCRIPT_DIR/../install.sh; prompt_download_method'" \
    0

# Test 5: Multiple invalid inputs (tests retry limit)
echo
run_test "Test 5: Multiple invalid inputs (retry limit test)" \
    "echo -e 'x\ny\nz\na\nb\nc' | bash -c 'source $SCRIPT_DIR/../install.sh; prompt_download_method'" \
    0

# Test 6: Valid input (option 1)
echo
run_test "Test 6: Valid input - option 1" \
    "echo '1' | bash -c 'source $SCRIPT_DIR/../install.sh; prompt_download_method'" \
    0

# Test 7: Valid input (option 4)
echo
run_test "Test 7: Valid input - option 4" \
    "echo '4' | bash -c 'source $SCRIPT_DIR/../install.sh; prompt_download_method'" \
    0

# Test 8: Detect mode function
echo
print_test "Test 8: Mode detection"
cd "$SCRIPT_DIR/.."
mode=$(bash -c 'source ./install.sh; detect_mode')
if [[ "$mode" == "local" ]]; then
    print_pass "Mode detection: local (correct)"
    pass_count=$((pass_count + 1))
else
    print_fail "Mode detection: $mode (expected: local)"
    fail_count=$((fail_count + 1))
fi
test_count=$((test_count + 1))

# Test 9: SSH setup non-interactive check
echo
run_test "Test 9: SSH setup non-interactive detection" \
    "bash -c 'source $SCRIPT_DIR/../install.sh; setup_git_ssh' < /dev/null" \
    1  # Expected to fail (returns 1) with proper error

# Test 10: Token get non-interactive check
echo
run_test "Test 10: Token input non-interactive detection" \
    "bash -c 'source $SCRIPT_DIR/../install.sh; get_github_token' < /dev/null" \
    1  # Expected to fail (returns 1) with proper error

echo
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Total tests: $test_count"
echo -e "${GREEN}Passed: $pass_count${NC}"
echo -e "${RED}Failed: $fail_count${NC}"
echo

# Cleanup
rm -f "$TEST_LOG"

if [[ $fail_count -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
