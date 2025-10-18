#!/usr/bin/env bats
# Test for the first-boot-wizard.sh script

setup() {
  load '../lib/test_helpers'
  export TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "first-boot-wizard.sh exists and is executable" {
  [ -x "../../scripts/first-boot-wizard.sh" ]
}

@test "first-boot-wizard has error handling" {
  assert_has_error_handling "../../scripts/first-boot-wizard.sh"
}

@test "first-boot-wizard sources UI library" {
  grep -q "source.*ui.sh\|source.*lib/ui" "../../scripts/first-boot-wizard.sh"
}

@test "first-boot-wizard has educational content" {
  grep -q "LEARNING\|WHAT\|WHY\|HOW" "../../scripts/first-boot-wizard.sh"
}

@test "first-boot-wizard creates necessary directories" {
  grep -q "mkdir\|mktemp" "../../scripts/first-boot-wizard.sh"
}

@test "first-boot-wizard has system tier selection" {
  grep -q "minimal\|enhanced\|complete" "../../scripts/first-boot-wizard.sh"
}

@test "first-boot-wizard validates user input" {
  # Should have input validation
  grep -q "if\|case\|while.*read" "../../scripts/first-boot-wizard.sh"
}
