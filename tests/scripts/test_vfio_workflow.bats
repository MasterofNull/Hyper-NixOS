#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for vfio_workflow
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/vfio_workflow.sh" ]
    [ -x "scripts/vfio_workflow.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/vfio_workflow.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/vfio_workflow.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
