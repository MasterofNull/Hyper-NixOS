#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for harden_permissions
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/harden_permissions.sh" ]
    [ -x "scripts/harden_permissions.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/harden_permissions.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/harden_permissions.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
