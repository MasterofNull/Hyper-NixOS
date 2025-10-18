#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for user_feedback
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/menu/lib/user_feedback.sh" ]
    [ -x "scripts/menu/lib/user_feedback.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/menu/lib/user_feedback.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/menu/lib/user_feedback.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
