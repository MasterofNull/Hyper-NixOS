#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for system_config_sudo
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/examples/system_config_sudo.sh" ]
    [ -x "scripts/examples/system_config_sudo.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/examples/system_config_sudo.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/examples/system_config_sudo.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
