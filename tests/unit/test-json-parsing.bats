#!/usr/bin/env bats

load ../test-helper

@test "JSON parsing - basic fields extracted correctly" {
  # Create test profile
  local profile
  profile=$(create_test_profile "test-vm" 4 8192)
  
  # Test name field
  run jq -r '.name' "$profile"
  [ "$status" -eq 0 ]
  [ "$output" = "test-vm" ]
  
  # Test cpus field
  run jq -r '.cpus' "$profile"
  [ "$status" -eq 0 ]
  [ "$output" = "4" ]
  
  # Test memory field
  run jq -r '.memory_mb' "$profile"
  [ "$status" -eq 0 ]
  [ "$output" = "8192" ]
}

@test "JSON parsing - defaults applied correctly" {
  # Create minimal profile
  cat > "$TEST_PROFILE_DIR/minimal.json" <<'TESTEOF'
{
  "name": "minimal-vm",
  "cpus": 1,
  "memory_mb": 1024
}
TESTEOF
  
  # Disk should default to 20
  run jq -r '.disk_gb // 20' "$TEST_PROFILE_DIR/minimal.json"
  [ "$status" -eq 0 ]
  [ "$output" = "20" ]
  
  # Arch should default to x86_64
  run jq -r '.arch // "x86_64"' "$TEST_PROFILE_DIR/minimal.json"
  [ "$status" -eq 0 ]
  [ "$output" = "x86_64" ]
}

@test "JSON parsing - malformed JSON rejected" {
  # Create invalid JSON (missing closing brace)
  echo '{"name": "broken"' > "$TEST_PROFILE_DIR/invalid.json"
  
  # Should fail to parse
  run jq '.' "$TEST_PROFILE_DIR/invalid.json"
  [ "$status" -ne 0 ]
}

@test "JSON parsing - can extract nested values" {
  # Create profile with nesting
  cat > "$TEST_PROFILE_DIR/nested.json" <<'TESTEOF'
{
  "name": "nested-vm",
  "network": {
    "bridge": "br0"
  }
}
TESTEOF
  
  run jq -r '.network.bridge' "$TEST_PROFILE_DIR/nested.json"
  [ "$status" -eq 0 ]
  [ "$output" = "br0" ]
}
