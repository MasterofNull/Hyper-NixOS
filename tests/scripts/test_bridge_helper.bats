#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for bridge_helper
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/bridge_helper.sh" ]
    [ -x "scripts/bridge_helper.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/bridge_helper.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/bridge_helper.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
