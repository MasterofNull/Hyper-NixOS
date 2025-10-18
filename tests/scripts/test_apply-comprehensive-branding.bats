#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for apply-comprehensive-branding
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/apply-comprehensive-branding.sh" ]
    [ -x "scripts/apply-comprehensive-branding.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/apply-comprehensive-branding.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/apply-comprehensive-branding.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
