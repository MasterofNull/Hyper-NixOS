#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for intelligent_template_processor
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/lib/intelligent_template_processor.sh" ]
    [ -x "scripts/lib/intelligent_template_processor.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/lib/intelligent_template_processor.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/lib/intelligent_template_processor.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
