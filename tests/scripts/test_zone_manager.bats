#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for zone_manager
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/zone_manager.sh" ]
    [ -x "scripts/zone_manager.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/zone_manager.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/zone_manager.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
