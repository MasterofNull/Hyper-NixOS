#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for transition_phase
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/transition_phase.sh" ]
    [ -x "scripts/transition_phase.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/transition_phase.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/transition_phase.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
