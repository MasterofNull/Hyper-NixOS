#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for dry_run
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/lib/dry_run.sh" ]
    [ -x "scripts/lib/dry_run.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/lib/dry_run.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/lib/dry_run.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
