#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for test-network-features
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/test-network-features.sh" ]
    [ -x "scripts/test-network-features.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/test-network-features.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/test-network-features.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
