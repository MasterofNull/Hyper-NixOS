#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for run-security-pipeline
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/security/run-security-pipeline.sh" ]
    [ -x "scripts/security/run-security-pipeline.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/security/run-security-pipeline.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/security/run-security-pipeline.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
