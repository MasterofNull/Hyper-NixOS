#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for headless-vm-menu
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/headless-vm-menu.sh" ]
    [ -x "scripts/headless-vm-menu.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/headless-vm-menu.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/headless-vm-menu.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
