#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for resource_reporter
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/resource_reporter.sh" ]
    [ -x "scripts/resource_reporter.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/resource_reporter.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/resource_reporter.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
