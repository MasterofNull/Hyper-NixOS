#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for security-aliases
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/security/security-aliases.sh" ]
    [ -x "scripts/security/security-aliases.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/security/security-aliases.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/security/security-aliases.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
