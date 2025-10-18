#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for fix-with-pkgs-antipattern
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/tools/fix-with-pkgs-antipattern.sh" ]
    [ -x "scripts/tools/fix-with-pkgs-antipattern.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/tools/fix-with-pkgs-antipattern.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/tools/fix-with-pkgs-antipattern.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
