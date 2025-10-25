#!/usr/bin/env bats
# Test for the main hv CLI entry point

setup() {
  load '../lib/test_helpers'
  export TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "hv script exists and is executable" {
  [ -x "../../scripts/hv" ]
}

@test "hv has shebang" {
  run head -n 1 ../../scripts/hv
  [[ "$output" =~ ^#!/ ]]
}

@test "hv shows help without arguments" {
  run ../../scripts/hv
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage:" ]] || [[ "$output" =~ "help" ]]
}

@test "hv help command works" {
  run ../../scripts/hv help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Hyper-NixOS" ]]
}

@test "hv has error handling" {
  assert_has_error_handling "../../scripts/hv"
}

@test "hv handles invalid command gracefully" {
  run ../../scripts/hv invalid-command-that-does-not-exist
  [ "$status" -ne 0 ]
  [[ "$output" =~ "Unknown\|Invalid\|Error" ]]
}

@test "hv lists available commands" {
  run ../../scripts/hv help
  [[ "$output" =~ "vm-create\|discover\|security" ]]
}
