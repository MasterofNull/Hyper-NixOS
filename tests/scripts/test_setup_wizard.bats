#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Test: Setup Wizard Script
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

# Load test helpers
load ../lib/test_helpers.bash

setup() {
    # Create temporary directory for test
    TEST_DIR="$(mktemp -d)"
    export TEST_DIR
}

teardown() {
    # Clean up temporary directory
    rm -rf "$TEST_DIR"
}

@test "setup wizard script exists and is executable" {
    [ -f "scripts/setup-wizard-old.sh" ]
    [ -x "scripts/setup-wizard-old.sh" ]
}

@test "setup wizard has proper shebang" {
    run head -1 scripts/setup-wizard-old.sh
    [[ "$output" == *"#!/usr/bin/env bash"* ]] || [[ "$output" == *"#!/bin/bash"* ]]
}

@test "setup wizard sources required libraries" {
    run grep -E "source.*lib/" scripts/setup-wizard-old.sh
    [ "$status" -eq 0 ]
}

@test "setup wizard has help function" {
    run grep -E "^(function )?show_help" scripts/setup-wizard-old.sh
    [ "$status" -eq 0 ] || {
        run grep -E "^(function )?usage" scripts/setup-wizard-old.sh
        [ "$status" -eq 0 ]
    }
}

@test "setup wizard uses error handling" {
    run grep "set -euo pipefail" scripts/setup-wizard-old.sh
    [ "$status" -eq 0 ] || {
        run grep "set -e" scripts/setup-wizard-old.sh
        [ "$status" -eq 0 ]
    }
}

@test "setup wizard validates sudo requirements" {
    run grep -E "REQUIRES_SUDO|require_sudo|check_sudo" scripts/setup-wizard-old.sh
    [ "$status" -eq 0 ]
}

@test "setup wizard creates configuration files" {
    run grep -E "hypervisor-features.nix|configuration" scripts/setup-wizard-old.sh
    [ "$status" -eq 0 ]
}

@test "setup wizard has system detection" {
    run grep -E "detect.*system|hardware.*detect" scripts/setup-wizard-old.sh
    [ "$status" -eq 0 ]
}

@test "setup wizard handles user input validation" {
    run grep -E "read -p|validate.*input" scripts/setup-wizard-old.sh
    [ "$status" -eq 0 ]
}

@test "setup wizard has educational content" {
    run grep -E "explain_|learning|educational" scripts/setup-wizard-old.sh
    [ "$status" -eq 0 ] || skip "Educational content optional for this wizard"
}
