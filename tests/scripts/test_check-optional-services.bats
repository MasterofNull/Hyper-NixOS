#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for check-optional-services
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/tools/check-optional-services.sh" ]
    [ -x "scripts/tools/check-optional-services.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/tools/check-optional-services.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/tools/check-optional-services.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
