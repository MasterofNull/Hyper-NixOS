#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for toggle_boot_features
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/toggle_boot_features.sh" ]
    [ -x "scripts/toggle_boot_features.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/toggle_boot_features.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/toggle_boot_features.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
