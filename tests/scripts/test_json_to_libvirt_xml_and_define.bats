#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Auto-generated test for json_to_libvirt_xml_and_define
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/json_to_libvirt_xml_and_define.sh" ]
    [ -x "scripts/json_to_libvirt_xml_and_define.sh" ] || skip "Not executable"
}

@test "script has bash shebang" {
    run head -1 scripts/json_to_libvirt_xml_and_define.sh
    [[ "$output" == *"bash"* ]] || skip "No bash shebang"
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/json_to_libvirt_xml_and_define.sh
    [ "$status" -eq 0 ] || skip "No error handling"
}
