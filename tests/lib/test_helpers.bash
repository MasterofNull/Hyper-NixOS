#!/bin/bash
# Common test helper functions for BATS tests

# File assertion helpers
assert_file_exists() {
  local file="$1"
  [ -f "$file" ] || fail "File $file does not exist"
}

assert_dir_exists() {
  local dir="$1"
  [ -d "$dir" ] || fail "Directory $dir does not exist"
}

assert_executable() {
  local file="$1"
  [ -x "$file" ] || fail "File $file is not executable"
}

# Module validation helpers
assert_module_has_options() {
  local module="$1"
  grep -q "options.hypervisor" "$module" || fail "Module $module missing options block"
}

assert_module_has_config() {
  local module="$1"
  grep -q "config =" "$module" || fail "Module $module missing config block"
}

assert_module_uses_mkif() {
  local module="$1"
  grep -q "lib.mkIf" "$module" || fail "Module $module should use lib.mkIf for conditional config"
}

# Script validation helpers
assert_has_error_handling() {
  local script="$1"
  grep -q "set -e" "$script" || fail "Script $script missing 'set -e'"
}

assert_has_help() {
  local script="$1"
  grep -q "help()\|--help\|-h" "$script" || fail "Script $script missing help function"
}

# Mock command helpers
mock_system_command() {
  local cmd="$1"
  local output="$2"
  local exit_code="${3:-0}"

  mkdir -p "$TEST_TMPDIR/mocks"
  export PATH="$TEST_TMPDIR/mocks:$PATH"

  cat > "$TEST_TMPDIR/mocks/$cmd" <<EOF
#!/bin/bash
echo '$output'
exit $exit_code
EOF
  chmod +x "$TEST_TMPDIR/mocks/$cmd"
}

mock_failing_command() {
  local cmd="$1"
  local error_msg="$2"
  mock_system_command "$cmd" "$error_msg" 1
}

# NixOS specific helpers
is_nixos() {
  [ -f /etc/NIXOS ] || [ -f /run/current-system/nixos-version ]
}

skip_if_not_nixos() {
  if ! is_nixos; then
    skip "This test requires NixOS"
  fi
}

has_libvirt() {
  command -v virsh >/dev/null 2>&1
}

skip_if_no_libvirt() {
  if ! has_libvirt; then
    skip "This test requires libvirt"
  fi
}

# String assertion helpers
assert_output_contains() {
  local expected="$1"
  [[ "$output" =~ $expected ]] || fail "Expected output to contain '$expected', got: $output"
}

assert_output_equals() {
  local expected="$1"
  [ "$output" = "$expected" ] || fail "Expected output '$expected', got: $output"
}

# Cleanup helpers
cleanup_temp_files() {
  rm -rf "$TEST_TMPDIR"/*
}

# Failure helper
fail() {
  echo "$@" >&2
  return 1
}
