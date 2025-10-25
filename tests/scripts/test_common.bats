#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
#
# Test: common Script
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

load ../lib/test_helpers.bash

setup() {
    TEST_DIR="$(mktemp -d)"
    export TEST_DIR
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "script exists and is executable" {
    [ -f "scripts/common.sh" ]
    [ -x "scripts/common.sh" ]
}

@test "script has proper shebang" {
    run head -1 scripts/common.sh
    [[ "$output" == *"#!/usr/bin/env bash"* ]] || [[ "$output" == *"#!/bin/bash"* ]]
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/common.sh
    [ "$status" -eq 0 ]
}

@test "script has help or usage function" {
    run grep -E "^(function )?(show_help|usage)" scripts/common.sh
    [ "$status" -eq 0 ] || skip "Help function optional"
}
