#!/usr/bin/env bash
#
# Hyper-NixOS Test Runner
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Runs all unit and integration tests
#

# Get script directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source test framework
source "$TEST_DIR/lib/test_framework.sh"

# Configuration
VERBOSE=false
TEST_PATTERN=""
TEST_TYPE="all" # all, unit, integration

# Usage
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Run Hyper-NixOS test suite.

Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    -t, --type TYPE     Run specific test type (unit, integration, all)
    -p, --pattern PAT   Only run tests matching pattern
    
Examples:
    $(basename "$0")                    # Run all tests
    $(basename "$0") --type unit        # Run only unit tests
    $(basename "$0") --pattern common   # Run tests matching "common"

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -t|--type)
            TEST_TYPE="$2"
            shift 2
            ;;
        -p|--pattern)
            TEST_PATTERN="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Header
echo "=================================="
echo "Hyper-NixOS Test Suite"
echo "=================================="
echo "Test type: $TEST_TYPE"
[[ -n "$TEST_PATTERN" ]] && echo "Pattern: $TEST_PATTERN"
echo ""

# Run unit tests
if [[ "$TEST_TYPE" == "all" ]] || [[ "$TEST_TYPE" == "unit" ]]; then
    echo -e "\n${BLUE}=== UNIT TESTS ===${NC}"
    
    # Find all unit test files
    while IFS= read -r -d '' test_file; do
        # Skip if pattern doesn't match
        if [[ -n "$TEST_PATTERN" ]] && [[ ! "$test_file" =~ $TEST_PATTERN ]]; then
            continue
        fi
        
        echo -e "\n${BLUE}Running:${NC} $test_file"
        
        # Run test file in subshell to isolate tests
        (
            cd "$TEST_DIR"
            bash "$test_file"
        )
    done < <(find "$TEST_DIR/unit" -name "test_*.sh" -type f -print0 | sort -z)
fi

# Run integration tests
if [[ "$TEST_TYPE" == "all" ]] || [[ "$TEST_TYPE" == "integration" ]]; then
    echo -e "\n${BLUE}=== INTEGRATION TESTS ===${NC}"
    
    # Check if integration tests exist
    if [[ -d "$TEST_DIR/integration" ]]; then
        while IFS= read -r -d '' test_file; do
            # Skip if pattern doesn't match
            if [[ -n "$TEST_PATTERN" ]] && [[ ! "$test_file" =~ $TEST_PATTERN ]]; then
                continue
            fi
            
            echo -e "\n${BLUE}Running:${NC} $test_file"
            
            # Run test file
            (
                cd "$TEST_DIR"
                bash "$test_file"
            )
        done < <(find "$TEST_DIR/integration" -name "test_*.sh" -type f -print0 | sort -z)
    else
        echo "No integration tests found"
    fi
fi

# Overall summary
echo -e "\n${BLUE}=================================="
echo "Overall Test Summary"
echo -e "==================================${NC}"

# Calculate totals from all test runs
test_summary