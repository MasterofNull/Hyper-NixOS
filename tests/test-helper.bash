#!/usr/bin/env bash
# Test helper functions for BATS tests

# Color output for test results
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Setup function - runs before each test
setup() {
  # Create temporary directory for test files
  export TEST_TEMP_DIR="$(mktemp -d -t hypervisor-test-XXXXXX)"
  export TEST_PROFILE_DIR="$TEST_TEMP_DIR/vm_profiles"
  export TEST_ISO_DIR="$TEST_TEMP_DIR/isos"
  export TEST_DISK_DIR="$TEST_TEMP_DIR/disks"
  
  mkdir -p "$TEST_PROFILE_DIR" "$TEST_ISO_DIR" "$TEST_DISK_DIR"
  
  # Set test environment variables
  export HYPERVISOR_REQUIRE_ISO_VERIFICATION=0
  export DIALOG="echo"
}

# Teardown function - runs after each test
teardown() {
  # Clean up temporary directory
  if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
    rm -rf "$TEST_TEMP_DIR"
  fi
}

# Create a test VM profile
create_test_profile() {
  local name="${1:-test-vm}"
  local cpus="${2:-2}"
  local memory="${3:-2048}"
  
  cat > "$TEST_PROFILE_DIR/${name}.json" <<EOF
{
  "name": "$name",
  "cpus": $cpus,
  "memory_mb": $memory,
  "disk_gb": 20,
  "arch": "x86_64",
  "network": {
    "bridge": "default"
  }
}
EOF
  
  echo "$TEST_PROFILE_DIR/${name}.json"
}

# Create a test ISO file (empty, just for testing)
create_test_iso() {
  local name="${1:-test.iso}"
  local iso_path="$TEST_ISO_DIR/$name"
  
  touch "$iso_path"
  touch "$iso_path.sha256.verified"
  
  echo "$iso_path"
}

# Assert command succeeds
assert_success() {
  if [[ "$status" -ne 0 ]]; then
    echo "Expected command to succeed, but it failed with status $status"
    echo "Output: $output"
    return 1
  fi
}

# Assert command fails
assert_failure() {
  if [[ "$status" -eq 0 ]]; then
    echo "Expected command to fail, but it succeeded"
    echo "Output: $output"
    return 1
  fi
}

# Assert output contains string
assert_output_contains() {
  local expected="$1"
  if [[ "$output" != *"$expected"* ]]; then
    echo "Expected output to contain: $expected"
    echo "Actual output: $output"
    return 1
  fi
}

# Assert output equals string
assert_output_equals() {
  local expected="$1"
  if [[ "$output" != "$expected" ]]; then
    echo "Expected output: $expected"
    echo "Actual output: $output"
    return 1
  fi
}

# Assert file exists
assert_file_exists() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "Expected file to exist: $file"
    return 1
  fi
}

# Assert file does not exist
assert_file_not_exists() {
  local file="$1"
  if [[ -f "$file" ]]; then
    echo "Expected file to not exist: $file"
    return 1
  fi
}

# Assert directory exists
assert_dir_exists() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    echo "Expected directory to exist: $dir"
    return 1
  fi
}

# Mock command
mock_command() {
  local cmd="$1"
  local return_code="${2:-0}"
  local output="${3:-}"
  
  eval "$cmd() { echo '$output'; return $return_code; }"
}

# Run command and capture output
run_command() {
  run "$@"
  export status=$?
  export output="$output"
}

# Print test info
test_info() {
  echo "# $1" >&3
}

# Print test warning
test_warn() {
  echo "# WARNING: $1" >&3
}

# Skip test with reason
skip_test() {
  skip "$1"
}
