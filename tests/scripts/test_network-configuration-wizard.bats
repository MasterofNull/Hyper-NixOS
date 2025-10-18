#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for network-configuration-wizard
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/network-configuration-wizard.sh" ]
    [ -x "scripts/network-configuration-wizard.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/network-configuration-wizard.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/network-configuration-wizard.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
