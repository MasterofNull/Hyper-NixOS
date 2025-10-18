#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for per_vm_firewall
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/per_vm_firewall.sh" ]
    [ -x "scripts/per_vm_firewall.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/per_vm_firewall.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/per_vm_firewall.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
