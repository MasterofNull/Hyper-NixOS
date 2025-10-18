#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for toggle_gui
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/toggle_gui.sh" ]
    [ -x "scripts/toggle_gui.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/toggle_gui.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/toggle_gui.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
