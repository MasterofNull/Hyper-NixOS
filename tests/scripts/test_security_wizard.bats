#!/usr/bin/env bats
# Test for security-configuration-wizard.sh

setup() {
  load '../lib/test_helpers'
  export TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "security-configuration-wizard exists and is executable" {
  [ -x "../../scripts/security-configuration-wizard.sh" ]
}

@test "security wizard has error handling" {
  assert_has_error_handling "../../scripts/security-configuration-wizard.sh"
}

@test "security wizard has security profile options" {
  grep -q "baseline\|strict\|paranoid" "../../scripts/security-configuration-wizard.sh"
}

@test "security wizard configures firewall" {
  grep -q "firewall\|iptables\|nftables" "../../scripts/security-configuration-wizard.sh"
}

@test "security wizard has educational content" {
  grep -q "LEARNING\|security\|WHAT\|WHY" "../../scripts/security-configuration-wizard.sh"
}

@test "security wizard creates backup before changes" {
  grep -q "backup\|cp.*\.bak" "../../scripts/security-configuration-wizard.sh"
}
