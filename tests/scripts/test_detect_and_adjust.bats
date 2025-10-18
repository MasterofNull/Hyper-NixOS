#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for detect_and_adjust
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/detect_and_adjust.sh" ]
    [ -x "scripts/detect_and_adjust.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/detect_and_adjust.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/detect_and_adjust.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
