#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for migrate-host-credentials
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/migrate-host-credentials.sh" ]
    [ -x "scripts/migrate-host-credentials.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/migrate-host-credentials.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/migrate-host-credentials.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
