#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
#
# Test: branding Script
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
    [ -f "scripts/branding.sh" ]
    [ -x "scripts/branding.sh" ]
}

@test "script has proper shebang" {
    run head -1 scripts/branding.sh
    [[ "$output" == *"#!/usr/bin/env bash"* ]] || [[ "$output" == *"#!/bin/bash"* ]]
}

@test "script uses error handling" {
    run grep -E "set -e" scripts/branding.sh
    [ "$status" -eq 0 ]
}

@test "script has help or usage function" {
    run grep -E "^(function )?(show_help|usage)" scripts/branding.sh
    [ "$status" -eq 0 ] || skip "Help function optional"
}
