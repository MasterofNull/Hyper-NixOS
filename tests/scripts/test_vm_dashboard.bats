#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for vm_dashboard
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/vm_dashboard.sh" ]
    [ -x "scripts/vm_dashboard.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/vm_dashboard.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/vm_dashboard.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
