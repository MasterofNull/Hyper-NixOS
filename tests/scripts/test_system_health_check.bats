#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for system_health_check
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/system_health_check.sh" ]
    [ -x "scripts/system_health_check.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/system_health_check.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/system_health_check.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
