#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for bulk_operations
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/bulk_operations.sh" ]
    [ -x "scripts/bulk_operations.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/bulk_operations.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/bulk_operations.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
