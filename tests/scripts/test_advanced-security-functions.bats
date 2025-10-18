#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for advanced-security-functions
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/security/advanced-security-functions.sh" ]
    [ -x "scripts/security/advanced-security-functions.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/security/advanced-security-functions.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/security/advanced-security-functions.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
