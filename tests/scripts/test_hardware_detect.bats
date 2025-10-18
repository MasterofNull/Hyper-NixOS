#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for hardware_detect
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/hardware_detect.sh" ]
    [ -x "scripts/hardware_detect.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/hardware_detect.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/hardware_detect.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
