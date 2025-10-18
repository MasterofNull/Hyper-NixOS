#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for check_network_ready
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/check_network_ready.sh" ]
    [ -x "scripts/check_network_ready.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/check_network_ready.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/check_network_ready.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
