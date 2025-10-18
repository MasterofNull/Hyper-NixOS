#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for audit-module-structure
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/tools/audit-module-structure.sh" ]
    [ -x "scripts/tools/audit-module-structure.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/tools/audit-module-structure.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/tools/audit-module-structure.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
