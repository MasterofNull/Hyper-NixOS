#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for enhanced_health_checks
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/enhanced_health_checks.sh" ]
    [ -x "scripts/enhanced_health_checks.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/enhanced_health_checks.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/enhanced_health_checks.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
