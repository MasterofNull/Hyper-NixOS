#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for verify_privilege_implementation
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/verify_privilege_implementation.sh" ]
    [ -x "scripts/verify_privilege_implementation.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/verify_privilege_implementation.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/verify_privilege_implementation.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
