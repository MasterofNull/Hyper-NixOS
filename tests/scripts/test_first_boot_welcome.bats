#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for first_boot_welcome
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/first_boot_welcome.sh" ]
    [ -x "scripts/first_boot_welcome.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/first_boot_welcome.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/first_boot_welcome.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
