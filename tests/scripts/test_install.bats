#!/usr/bin/env bats
# Test for the install.sh script

setup() {
  load '../lib/test_helpers'
  export TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "install.sh exists and is executable" {
  [ -x "../../install.sh" ]
}

@test "install.sh has shebang" {
  run head -n 1 ../../install.sh
  [[ "$output" =~ ^#!/ ]]
}

@test "install.sh has error handling" {
  assert_has_error_handling "../../install.sh"
}

@test "install.sh has help function" {
  # Check if help text exists
  grep -q "Usage:\|help()\|--help" "../../install.sh"
}

@test "install.sh checks for root privileges" {
  grep -q "root\|EUID\|sudo" "../../install.sh"
}

@test "install.sh validates system requirements" {
  grep -q "nixos\|nix-" "../../install.sh"
}

@test "install.sh has safety checks" {
  # Should check before modifying system
  grep -q "confirm\|yes\|no" "../../install.sh"
}
