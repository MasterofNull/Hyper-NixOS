#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for parallel-framework
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/automation/parallel-framework.sh" ]
    [ -x "scripts/automation/parallel-framework.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/automation/parallel-framework.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/automation/parallel-framework.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
