#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for standardize-all-scripts
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/tools/standardize-all-scripts.sh" ]
    [ -x "scripts/tools/standardize-all-scripts.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/tools/standardize-all-scripts.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/tools/standardize-all-scripts.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
