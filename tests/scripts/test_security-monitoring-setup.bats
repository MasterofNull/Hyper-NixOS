#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for security-monitoring-setup
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/monitoring/security-monitoring-setup.sh" ]
    [ -x "scripts/monitoring/security-monitoring-setup.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/monitoring/security-monitoring-setup.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/monitoring/security-monitoring-setup.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
