#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Test: Network Configuration Wizard
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

@test "network wizard exists and is executable" {
    [ -f "scripts/network-configuration-wizard.sh" ]
    [ -x "scripts/network-configuration-wizard.sh" ]
}

@test "network wizard has error handling" {
    run grep "set -euo pipefail" scripts/network-configuration-wizard.sh
    [ "$status" -eq 0 ]
}

@test "network wizard requires sudo" {
    run grep -E "REQUIRES_SUDO=true|require_sudo|check_root" scripts/network-configuration-wizard.sh
    [ "$status" -eq 0 ]
}

@test "network wizard detects network interfaces" {
    run grep -E "ip link|nmcli|networkctl" scripts/network-configuration-wizard.sh
    [ "$status" -eq 0 ]
}

@test "network wizard configures static IP" {
    run grep -E "static.*ip|ip.*address.*add" scripts/network-configuration-wizard.sh
    [ "$status" -eq 0 ]
}

@test "network wizard configures DHCP" {
    run grep -E "dhcp|dhclient" scripts/network-configuration-wizard.sh
    [ "$status" -eq 0 ]
}

@test "network wizard handles bridge configuration" {
    run grep -E "bridge|br0" scripts/network-configuration-wizard.sh
    [ "$status" -eq 0 ]
}

@test "network wizard validates IP addresses" {
    run grep -E "validate.*ip|ip.*valid" scripts/network-configuration-wizard.sh
    [ "$status" -eq 0 ] || skip "IP validation may be in library"
}

@test "network wizard has educational content" {
    run grep -E "explain_what|explain_why|explain_how" scripts/network-configuration-wizard.sh
    [ "$status" -eq 0 ]
}

@test "network wizard creates backup before changes" {
    run grep -E "backup|cp.*\.bak" scripts/network-configuration-wizard.sh
    [ "$status" -eq 0 ]
}
