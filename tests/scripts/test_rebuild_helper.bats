#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for rebuild_helper
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/rebuild_helper.sh" ]
    [ -x "scripts/rebuild_helper.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/rebuild_helper.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/rebuild_helper.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
