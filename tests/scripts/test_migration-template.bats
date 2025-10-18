#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for migration-template
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/lib/migration-template.sh" ]
    [ -x "scripts/lib/migration-template.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/lib/migration-template.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/lib/migration-template.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
