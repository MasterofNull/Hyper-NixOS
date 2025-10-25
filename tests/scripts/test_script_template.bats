#!/usr/bin/env bats
# BATS test template for shell scripts
# Install BATS: nix-shell -p bats

setup() {
  # Load test helpers if available
  if [ -f "../lib/test_helpers.bash" ]; then
    load '../lib/test_helpers'
  fi

  # Create temporary directory for test isolation
  export TEST_TMPDIR="$(mktemp -d)"
  export ORIGINAL_PWD="$PWD"
  cd "$TEST_TMPDIR"
}

teardown() {
  # Cleanup temporary files
  cd "$ORIGINAL_PWD"
  rm -rf "$TEST_TMPDIR"
}

@test "script exists and is executable" {
  [ -x "../../scripts/script-name.sh" ]
}

@test "script has shebang" {
  run head -n 1 ../../scripts/script-name.sh
  [[ "$output" =~ ^#!/ ]]
}

@test "script has help function" {
  run ../../scripts/script-name.sh --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage:" ]]
}

@test "script validates inputs" {
  run ../../scripts/script-name.sh invalid-input
  [ "$status" -ne 0 ]
}

@test "script produces expected output" {
  run ../../scripts/script-name.sh valid-input
  [ "$status" -eq 0 ]
  [[ "$output" =~ "expected-string" ]]
}

@test "script handles missing dependencies gracefully" {
  # Mock missing command
  export PATH="$TEST_TMPDIR/mock:$PATH"
  mkdir -p "$TEST_TMPDIR/mock"

  run ../../scripts/script-name.sh
  # Should either skip gracefully or provide clear error
  [ "$status" -ne 0 ] || [[ "$output" =~ "skip" ]]
}
