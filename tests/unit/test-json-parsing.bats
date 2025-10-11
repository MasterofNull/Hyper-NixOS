#!/usr/bin/env bats

load ../test-helper

@test "JSON parsing - basic fields extracted correctly" {
  # Create test profile
  profile=$(create_test_profile "test-vm" 4 8192)
  
  # Test each field
  run jq -r '.name' "$profile"
  [ "$status" -eq 0 ]
  [ "$output" = "test-vm" ]
  
  run jq -r '.cpus' "$profile"
  [ "$status" -eq 0 ]
  [ "$output" = "4" ]
  
  run jq -r '.memory_mb' "$profile"
  [ "$status" -eq 0 ]
  [ "$output" = "8192" ]
}

@test "JSON parsing - defaults applied correctly" {
  # Create minimal profile
  cat > "$TEST_PROFILE_DIR/minimal.json" <<EOF
{
  "name": "minimal-vm",
  "cpus": 1,
  "memory_mb": 1024
}
EOF
  
  # Disk should default to 20
  run jq -r '.disk_gb // 20' "$TEST_PROFILE_DIR/minimal.json"
  [ "$status" -eq 0 ]
  [ "$output" = "20" ]
  
  # Arch should default to x86_64
  run jq -r '.arch // "x86_64"' "$TEST_PROFILE_DIR/minimal.json"
  [ "$status" -eq 0 ]
  [ "$output" = "x86_64" ]
}

@test "JSON parsing - complex nested fields" {
  # Create profile with nested fields
  cat > "$TEST_PROFILE_DIR/complex.json" <<EOF
{
  "name": "complex-vm",
  "cpus": 2,
  "memory_mb": 2048,
  "network": {
    "bridge": "br0",
    "zone": "secure"
  },
  "cpu_features": {
    "sev": true,
    "avic": false
  }
}
EOF
  
  # Test nested fields
  run jq -r '.network.bridge' "$TEST_PROFILE_DIR/complex.json"
  [ "$status" -eq 0 ]
  [ "$output" = "br0" ]
  
  run jq -r '.cpu_features.sev' "$TEST_PROFILE_DIR/complex.json"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "JSON parsing - array fields handled" {
  # Create profile with arrays
  cat > "$TEST_PROFILE_DIR/arrays.json" <<EOF
{
  "name": "array-vm",
  "cpus": 2,
  "memory_mb": 2048,
  "hostdevs": ["0000:01:00.0", "0000:01:00.1"],
  "cpu_pinning": [0, 1]
}
EOF
  
  # Test array parsing
  run jq -r '.hostdevs | length' "$TEST_PROFILE_DIR/arrays.json"
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
  
  run jq -r '.hostdevs[0]' "$TEST_PROFILE_DIR/arrays.json"
  [ "$status" -eq 0 ]
  [ "$output" = "0000:01:00.0" ]
}

@test "JSON parsing - malformed JSON rejected" {
  # Create invalid JSON
  cat > "$TEST_PROFILE_DIR/invalid.json" <<EOF
{
  "name": "broken-vm",
  "cpus": 2,
  "memory_mb": 2048
  # missing closing brace
EOF
  
  # Should fail to parse
  run jq '.' "$TEST_PROFILE_DIR/invalid.json"
  [ "$status" -ne 0 ]
}
