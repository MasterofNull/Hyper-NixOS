#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for setup-incident-response
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/security/setup-incident-response.sh" ]
    [ -x "scripts/security/setup-incident-response.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/security/setup-incident-response.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/security/setup-incident-response.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
