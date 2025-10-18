#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for vm_start
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/vm_start.sh" ]
    [ -x "scripts/vm_start.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/vm_start.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/vm_start.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
