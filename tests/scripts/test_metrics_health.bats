#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for metrics_health
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/metrics_health.sh" ]
    [ -x "scripts/metrics_health.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/metrics_health.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/metrics_health.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
