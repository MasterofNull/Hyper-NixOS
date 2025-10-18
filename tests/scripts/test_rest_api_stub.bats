#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for rest_api_stub
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/rest_api_stub.sh" ]
    [ -x "scripts/rest_api_stub.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/rest_api_stub.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/rest_api_stub.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
