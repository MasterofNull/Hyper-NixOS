#!/usr/bin/env bash
#
# Hyper-NixOS Test Framework
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Simple but effective test framework for bash scripts
#

# Test statistics
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
CURRENT_TEST=""
CURRENT_TEST_FILE=""

# Colors for output
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Test assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"
    
    if [[ "$expected" == "$actual" ]]; then
        pass "$message"
    else
        fail "$message: expected='$expected', actual='$actual'"
    fi
}

assert_not_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should not be equal}"
    
    if [[ "$expected" != "$actual" ]]; then
        pass "$message"
    else
        fail "$message: both values are '$expected'"
    fi
}

assert_true() {
    local condition="$1"
    local message="${2:-Condition should be true}"
    
    if [[ "$condition" == "true" ]] || [[ "$condition" == "0" ]]; then
        pass "$message"
    else
        fail "$message: condition='$condition'"
    fi
}

assert_false() {
    local condition="$1"
    local message="${2:-Condition should be false}"
    
    if [[ "$condition" == "false" ]] || [[ "$condition" != "0" ]]; then
        pass "$message"
    else
        fail "$message: condition='$condition'"
    fi
}

assert_success() {
    local exit_code="$?"
    local message="${1:-Command should succeed}"
    
    if [[ "$exit_code" -eq 0 ]]; then
        pass "$message"
    else
        fail "$message: exit_code=$exit_code"
    fi
}

assert_failure() {
    local exit_code="$?"
    local message="${1:-Command should fail}"
    
    if [[ "$exit_code" -ne 0 ]]; then
        pass "$message"
    else
        fail "$message: command succeeded when it should have failed"
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain substring}"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        pass "$message"
    else
        fail "$message: '$haystack' does not contain '$needle'"
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should not contain substring}"
    
    if [[ "$haystack" != *"$needle"* ]]; then
        pass "$message"
    else
        fail "$message: '$haystack' contains '$needle'"
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist}"
    
    if [[ -f "$file" ]]; then
        pass "$message"
    else
        fail "$message: file '$file' does not exist"
    fi
}

assert_file_not_exists() {
    local file="$1"
    local message="${2:-File should not exist}"
    
    if [[ ! -f "$file" ]]; then
        pass "$message"
    else
        fail "$message: file '$file' exists"
    fi
}

assert_directory_exists() {
    local dir="$1"
    local message="${2:-Directory should exist}"
    
    if [[ -d "$dir" ]]; then
        pass "$message"
    else
        fail "$message: directory '$dir' does not exist"
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$?"
    local message="${2:-Exit code should match}"
    
    if [[ "$expected" -eq "$actual" ]]; then
        pass "$message"
    else
        fail "$message: expected=$expected, actual=$actual"
    fi
}

# Test lifecycle functions
test() {
    local test_name="$1"
    CURRENT_TEST="$test_name"
    ((TESTS_RUN++))
    echo -e "\n  ${BLUE}TEST:${NC} $test_name"
}

skip() {
    local reason="${1:-No reason provided}"
    ((TESTS_SKIPPED++))
    echo -e "    ${YELLOW}SKIP${NC} $reason"
    CURRENT_TEST=""
}

pass() {
    local message="$1"
    ((TESTS_PASSED++))
    echo -e "    ${GREEN}✓${NC} $message"
}

fail() {
    local message="$1"
    ((TESTS_FAILED++))
    echo -e "    ${RED}✗${NC} $message"
    if [[ -n "$CURRENT_TEST" ]]; then
        echo -e "      in test: $CURRENT_TEST"
    fi
    if [[ -n "$CURRENT_TEST_FILE" ]]; then
        echo -e "      in file: $CURRENT_TEST_FILE"
    fi
}

# Setup and teardown
setup() {
    # Override in test files
    true
}

teardown() {
    # Override in test files
    true
}

# Test suite functions
test_suite() {
    local suite_name="$1"
    echo -e "\n${BLUE}TEST SUITE:${NC} $suite_name"
    CURRENT_TEST_FILE="$suite_name"
}

run_test_file() {
    local test_file="$1"
    
    if [[ ! -f "$test_file" ]]; then
        echo -e "${RED}ERROR:${NC} Test file not found: $test_file"
        return 1
    fi
    
    # Source the test file
    source "$test_file"
    
    # Run setup
    setup
    
    # Run all functions that start with test_
    local test_functions
    test_functions=$(declare -F | awk '$3 ~ /^test_/ {print $3}')
    
    for func in $test_functions; do
        # Run the test function
        "$func"
    done
    
    # Run teardown
    teardown
}

# Summary function
test_summary() {
    echo -e "\n${BLUE}========== TEST SUMMARY ==========${NC}"
    echo -e "Tests run:     $TESTS_RUN"
    echo -e "Tests passed:  ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed:  ${RED}$TESTS_FAILED${NC}"
    echo -e "Tests skipped: ${YELLOW}$TESTS_SKIPPED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}Some tests failed!${NC}"
        return 1
    fi
}

# Mock functions for testing
mock_function() {
    local func_name="$1"
    local mock_impl="$2"
    
    # Save original function if it exists
    if declare -F "$func_name" >/dev/null; then
        eval "original_$func_name() { $(declare -f "$func_name" | tail -n +2) }"
    fi
    
    # Create mock
    eval "$func_name() { $mock_impl; }"
}

restore_function() {
    local func_name="$1"
    
    # Restore original if it exists
    if declare -F "original_$func_name" >/dev/null; then
        eval "$func_name() { $(declare -f "original_$func_name" | tail -n +2) }"
        unset -f "original_$func_name"
    else
        unset -f "$func_name"
    fi
}

# Capture output for testing
capture_output() {
    local command="$1"
    local stdout_var="$2"
    local stderr_var="$3"
    local exit_code_var="$4"
    
    local stdout_file=$(mktemp)
    local stderr_file=$(mktemp)
    
    # Run command and capture output
    local exit_code=0
    eval "$command" >"$stdout_file" 2>"$stderr_file" || exit_code=$?
    
    # Store results
    eval "$stdout_var=\"\$(cat \"$stdout_file\")\""
    eval "$stderr_var=\"\$(cat \"$stderr_file\")\""
    eval "$exit_code_var=\"$exit_code\""
    
    # Cleanup
    rm -f "$stdout_file" "$stderr_file"
}

# Export all functions
export -f assert_equals assert_not_equals assert_true assert_false
export -f assert_success assert_failure assert_contains assert_not_contains
export -f assert_file_exists assert_file_not_exists assert_directory_exists
export -f assert_exit_code test skip pass fail setup teardown
export -f test_suite run_test_file test_summary mock_function restore_function
export -f capture_output