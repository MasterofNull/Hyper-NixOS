#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for guided_system_test
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/guided_system_test.sh" ]
    [ -x "scripts/guided_system_test.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/guided_system_test.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/guided_system_test.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
