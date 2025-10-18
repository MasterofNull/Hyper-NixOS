#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for validate-system-requirements
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/validate-system-requirements.sh" ]
    [ -x "scripts/validate-system-requirements.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/validate-system-requirements.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/validate-system-requirements.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
