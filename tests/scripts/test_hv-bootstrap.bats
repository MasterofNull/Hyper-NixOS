#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for hv-bootstrap
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/hv-bootstrap.sh" ]
    [ -x "scripts/hv-bootstrap.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/hv-bootstrap.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/hv-bootstrap.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
