#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for detect_gui_environment
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/detect_gui_environment.sh" ]
    [ -x "scripts/detect_gui_environment.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/detect_gui_environment.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/detect_gui_environment.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
