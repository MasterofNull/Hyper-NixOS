#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for automated_backup
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/automated_backup.sh" ]
    [ -x "scripts/automated_backup.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/automated_backup.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/automated_backup.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
