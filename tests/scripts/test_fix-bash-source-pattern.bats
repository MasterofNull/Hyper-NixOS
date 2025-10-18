#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for fix-bash-source-pattern
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/tools/fix-bash-source-pattern.sh" ]
    [ -x "scripts/tools/fix-bash-source-pattern.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/tools/fix-bash-source-pattern.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/tools/fix-bash-source-pattern.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
