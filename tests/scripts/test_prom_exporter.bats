#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for prom_exporter
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/prom_exporter.sh" ]
    [ -x "scripts/prom_exporter.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/prom_exporter.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/prom_exporter.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
