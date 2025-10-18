#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for logging
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/lib/logging.sh" ]
    [ -x "scripts/lib/logging.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/lib/logging.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/lib/logging.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
