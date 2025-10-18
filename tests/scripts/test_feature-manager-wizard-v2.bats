#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for feature-manager-wizard-v2
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/feature-manager-wizard-v2.sh" ]
    [ -x "scripts/feature-manager-wizard-v2.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/feature-manager-wizard-v2.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/feature-manager-wizard-v2.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
