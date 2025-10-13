#!/usr/bin/env bash
#
# Unit tests for common.sh library
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#

# Get the directory of this script
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$TEST_DIR/../../scripts" && pwd)"

# Source test framework
source "$TEST_DIR/../lib/test_framework.sh"

# Source the library being tested
source "$SCRIPTS_DIR/lib/common.sh"
source "$SCRIPTS_DIR/lib/exit_codes.sh"

# Test suite
test_suite "common.sh library"

# Setup function
setup() {
    # Create temporary directory for tests
    TEST_TEMP_DIR=$(mktemp -d -t hypervisor-test.XXXXXX)
    export HYPERVISOR_LOGS="$TEST_TEMP_DIR/logs"
    mkdir -p "$HYPERVISOR_LOGS"
}

# Teardown function
teardown() {
    # Clean up temporary directory
    [[ -d "$TEST_TEMP_DIR" ]] && rm -rf "$TEST_TEMP_DIR"
}

# Test validate_vm_name function
test_validate_vm_name() {
    test "validate_vm_name with valid names"
    
    validate_vm_name "valid-vm-name"
    assert_success "Should accept hyphenated names"
    
    validate_vm_name "vm_with_underscore"
    assert_success "Should accept underscored names"
    
    validate_vm_name "VM123"
    assert_success "Should accept alphanumeric names"
}

test_validate_vm_name_invalid() {
    test "validate_vm_name with invalid names"
    
    validate_vm_name "vm with spaces" || true
    assert_failure "Should reject names with spaces"
    
    validate_vm_name "../evil" || true
    assert_failure "Should reject path traversal attempts"
    
    validate_vm_name "/absolute/path" || true
    assert_failure "Should reject absolute paths"
    
    validate_vm_name "vm@special" || true
    assert_failure "Should reject special characters"
    
    validate_vm_name "" || true
    assert_failure "Should reject empty names"
}

# Test validate_path function
test_validate_path() {
    test "validate_path with valid paths"
    
    validate_path "/tmp/test"
    assert_success "Should accept absolute paths"
    
    validate_path "relative/path"
    assert_success "Should accept relative paths"
    
    validate_path "$TEST_TEMP_DIR/subdir" "$TEST_TEMP_DIR"
    assert_success "Should accept paths within base directory"
}

test_validate_path_invalid() {
    test "validate_path with invalid paths"
    
    validate_path "/tmp/../etc/passwd" || true
    assert_failure "Should reject path traversal"
    
    validate_path "/outside/path" "/restricted" || true
    assert_failure "Should reject paths outside base directory"
}

# Test json_get function
test_json_get() {
    test "json_get function"
    
    # Create test JSON file
    local json_file="$TEST_TEMP_DIR/test.json"
    cat > "$json_file" <<EOF
{
    "name": "test-vm",
    "memory": 2048,
    "enabled": true,
    "nested": {
        "value": "nested-value"
    }
}
EOF
    
    local result
    result=$(json_get "$json_file" ".name" "default")
    assert_equals "test-vm" "$result" "Should get string value"
    
    result=$(json_get "$json_file" ".memory" "0")
    assert_equals "2048" "$result" "Should get numeric value"
    
    result=$(json_get "$json_file" ".enabled" "false")
    assert_equals "true" "$result" "Should get boolean value"
    
    result=$(json_get "$json_file" ".nested.value" "default")
    assert_equals "nested-value" "$result" "Should get nested value"
    
    result=$(json_get "$json_file" ".missing" "default-value")
    assert_equals "default-value" "$result" "Should return default for missing key"
    
    result=$(json_get "/nonexistent/file.json" ".key" "default")
    assert_equals "default" "$result" "Should return default for missing file"
}

# Test make_temp_file function
test_make_temp_file() {
    test "make_temp_file function"
    
    local temp_file
    temp_file=$(make_temp_file "test-prefix")
    assert_success "Should create temporary file"
    assert_file_exists "$temp_file" "Temporary file should exist"
    assert_contains "$temp_file" "test-prefix" "Should use provided prefix"
}

# Test make_temp_dir function
test_make_temp_dir() {
    test "make_temp_dir function"
    
    local temp_dir
    temp_dir=$(make_temp_dir "test-prefix")
    assert_success "Should create temporary directory"
    assert_directory_exists "$temp_dir" "Temporary directory should exist"
    assert_contains "$temp_dir" "test-prefix" "Should use provided prefix"
}

# Test logging functions
test_logging() {
    test "logging functions"
    
    # Initialize logging
    init_logging "test-log"
    
    # Test log functions
    log_info "Test info message"
    assert_file_exists "$HYPERVISOR_LOGS/test-log.log" "Log file should be created"
    
    log_warn "Test warning"
    log_error "Test error"
    log_debug "Test debug" # Should not appear unless DEBUG=true
    
    # Check log contents
    local log_contents
    log_contents=$(cat "$HYPERVISOR_LOGS/test-log.log")
    assert_contains "$log_contents" "Test info message" "Should contain info message"
    assert_contains "$log_contents" "Test warning" "Should contain warning"
    assert_contains "$log_contents" "Test error" "Should contain error"
    assert_not_contains "$log_contents" "Test debug" "Should not contain debug by default"
}

# Test require function
test_require() {
    test "require function"
    
    # Test with existing commands
    require bash test
    assert_success "Should succeed for existing commands"
    
    # Test with non-existent command
    require nonexistent_command_xyz 2>/dev/null || true
    assert_failure "Should fail for missing commands"
}

# Test exit_with_error function
test_exit_with_error() {
    test "exit_with_error function"
    
    # Mock the exit function to prevent actual exit
    mock_function "exit" "echo EXIT_CODE=\$1"
    
    local output
    output=$(exit_with_error $EXIT_VM_ERROR "Test error message" 2>&1)
    
    assert_contains "$output" "EXIT_CODE=7" "Should exit with correct code"
    assert_contains "$output" "ERROR: Test error message" "Should print error message"
    
    # Restore exit function
    restore_function "exit"
}

# Test get_exit_code_description function
test_get_exit_code_description() {
    test "get_exit_code_description function"
    
    local desc
    desc=$(get_exit_code_description 0)
    assert_equals "Success" "$desc" "Should describe success code"
    
    desc=$(get_exit_code_description 2)
    assert_equals "Missing dependency" "$desc" "Should describe dependency error"
    
    desc=$(get_exit_code_description 999)
    assert_contains "$desc" "Unknown error code: 999" "Should handle unknown codes"
}

# Test performance monitoring functions
test_performance_monitoring() {
    test "performance monitoring functions"
    
    # Enable metrics
    SCRIPT_METRICS_ENABLED=true
    
    # Start timer
    script_timer_start
    assert_not_equals "" "$SCRIPT_START_TIME" "Should set start time"
    
    # Sleep briefly
    sleep 0.1
    
    # End timer
    script_timer_end "Test operation"
    
    # Check metrics file
    local metrics_file="$HYPERVISOR_LOGS/script_metrics.csv"
    if [[ -f "$metrics_file" ]]; then
        local metrics
        metrics=$(tail -n1 "$metrics_file")
        assert_contains "$metrics" "Test operation" "Should record operation name"
    fi
}

# Test measure_function
test_measure_function() {
    test "measure_function wrapper"
    
    # Create a test function
    test_func() {
        echo "Function output"
        return 42
    }
    
    # Measure it
    local output
    output=$(measure_function test_func)
    local exit_code=$?
    
    assert_equals "Function output" "$output" "Should capture function output"
    assert_equals "42" "$exit_code" "Should preserve exit code"
}

# Run all tests
run_all_tests() {
    test_validate_vm_name
    test_validate_vm_name_invalid
    test_validate_path
    test_validate_path_invalid
    test_json_get
    test_make_temp_file
    test_make_temp_dir
    test_logging
    test_require
    test_exit_with_error
    test_get_exit_code_description
    test_performance_monitoring
    test_measure_function
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
    test_summary
fi