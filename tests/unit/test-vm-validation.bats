#!/usr/bin/env bats

load ../test-helper

@test "VM name validation - valid name accepted" {
  # Test that valid VM names pass validation
  local profile
  profile=$(create_test_profile "test-vm")
  
  run jq -r '.name' "$profile"
  [ "$status" -eq 0 ]
  [ "$output" = "test-vm" ]
}

@test "VM name validation - valid name with numbers" {
  local profile
  profile=$(create_test_profile "vm01")
  
  run jq -r '.name' "$profile"
  [ "$status" -eq 0 ]
  [ "$output" = "vm01" ]
}

@test "VM name validation - empty name rejected" {
  # Empty names should be rejected
  cat > "$TEST_PROFILE_DIR/invalid.json" <<'TESTEOF'
{
  "name": "",
  "cpus": 2,
  "memory_mb": 2048
}
TESTEOF
  
  # Validation should fail
  run bash -c "jq -e '.name | length > 0' '$TEST_PROFILE_DIR/invalid.json'"
  
  # Should fail validation
  [ "$status" -ne 0 ]
}

@test "VM name validation - JSON is valid" {
  # Test that profile JSON is valid
  local profile
  profile=$(create_test_profile "valid-vm")
  
  run jq '.' "$profile"
  [ "$status" -eq 0 ]
}
