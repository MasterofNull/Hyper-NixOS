#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for migrate_0.9_to_1.0
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/migrations/migrate_0.9_to_1.0.sh" ]
    [ -x "scripts/migrations/migrate_0.9_to_1.0.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/migrations/migrate_0.9_to_1.0.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/migrations/migrate_0.9_to_1.0.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
