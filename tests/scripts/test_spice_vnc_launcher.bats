#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for spice_vnc_launcher
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/spice_vnc_launcher.sh" ]
    [ -x "scripts/spice_vnc_launcher.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/spice_vnc_launcher.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/spice_vnc_launcher.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
