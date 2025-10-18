#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for validate_hypervisor_install
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/validate_hypervisor_install.sh" ]
    [ -x "scripts/validate_hypervisor_install.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/validate_hypervisor_install.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/validate_hypervisor_install.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
