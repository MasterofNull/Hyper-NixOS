#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for install-hv-cli
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/install-hv-cli.sh" ]
    [ -x "scripts/install-hv-cli.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/install-hv-cli.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/install-hv-cli.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
