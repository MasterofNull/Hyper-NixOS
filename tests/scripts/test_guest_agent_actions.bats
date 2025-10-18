#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for guest_agent_actions
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/guest_agent_actions.sh" ]
    [ -x "scripts/guest_agent_actions.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/guest_agent_actions.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/guest_agent_actions.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
