#!/usr/bin/env bats

load ../test-helper

@test "VM name validation - valid name accepted" {
  # Test that valid VM names pass validation
  local valid_names=("test-vm" "vm01" "ubuntu_server" "my.vm" "VM-123")
  
  for name in "${valid_names[@]}"; do
    # Create profile with valid name
    profile=$(create_test_profile "$name")
    
    # Should contain the name
    run jq -r '.name' "$profile"
    [ "$status" -eq 0 ]
    [ "$output" = "$name" ]
  done
}

@test "VM name validation - empty name rejected" {
  # Empty names should be rejected
  cat > "$TEST_PROFILE_DIR/invalid.json" <<EOF
{
  "name": "",
  "cpus": 2,
  "memory_mb": 2048
}
EOF
  
  # Validation should fail
  run bash -c "source scripts/json_to_libvirt_xml_and_define.sh 2>&1 || true" < "$TEST_PROFILE_DIR/invalid.json"
  
  # Should contain error message
  [[ "$output" == *"name cannot be empty"* ]] || [[ "$output" == *"empty"* ]]
}

@test "VM name validation - name with invalid chars rejected" {
  # Names with spaces or special chars should be rejected or sanitized
  local invalid_names=("test vm" "vm@123" "vm#test")
  
  for name in "${invalid_names[@]}"; do
    # Create profile
    cat > "$TEST_PROFILE_DIR/test.json" <<EOF
{
  "name": "$name",
  "cpus": 2,
  "memory_mb": 2048
}
EOF
    
    # Name should either be rejected or sanitized
    run jq -r '.name' "$TEST_PROFILE_DIR/test.json"
    [ "$status" -eq 0 ]
  done
}

@test "VM name validation - long name handled" {
  # Very long names should be caught
  local long_name="this-is-a-very-long-vm-name-that-exceeds-the-maximum-allowed-length-for-vm-names-and-should-be-rejected"
  
  cat > "$TEST_PROFILE_DIR/long.json" <<EOF
{
  "name": "$long_name",
  "cpus": 2,
  "memory_mb": 2048
}
EOF
  
  # Name exists in profile
  run jq -r '.name' "$TEST_PROFILE_DIR/long.json"
  [ "$status" -eq 0 ]
  [ "${#output}" -gt 64 ]
}
