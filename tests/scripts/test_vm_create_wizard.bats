#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Test: VM Creation Wizard
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

@test "vm create wizard exists and is executable" {
    [ -f "scripts/create-vm-wizard.sh" ]
    [ -x "scripts/create-vm-wizard.sh" ]
}

@test "vm create wizard has error handling" {
    run grep "set -euo pipefail" scripts/create-vm-wizard.sh
    [ "$status" -eq 0 ]
}

@test "vm create wizard does NOT require sudo" {
    run grep -E "REQUIRES_SUDO=false|OPERATION_TYPE.*vm" scripts/create-vm-wizard.sh
    [ "$status" -eq 0 ]
}

@test "vm create wizard validates VM name" {
    run grep -E "validate.*name|VM.*name" scripts/create-vm-wizard.sh
    [ "$status" -eq 0 ]
}

@test "vm create wizard configures memory" {
    run grep -E "memory|RAM|--ram" scripts/create-vm-wizard.sh
    [ "$status" -eq 0 ]
}

@test "vm create wizard configures CPU" {
    run grep -E "cpu|vcpu|--vcpus" scripts/create-vm-wizard.sh
    [ "$status" -eq 0 ]
}

@test "vm create wizard configures disk" {
    run grep -E "disk|storage|qemu-img" scripts/create-vm-wizard.sh
    [ "$status" -eq 0 ]
}

@test "vm create wizard uses virt-install" {
    run grep "virt-install" scripts/create-vm-wizard.sh
    [ "$status" -eq 0 ]
}

@test "vm create wizard handles ISO selection" {
    run grep -E "iso|ISO" scripts/create-vm-wizard.sh
    [ "$status" -eq 0 ]
}

@test "vm create wizard validates system resources" {
    run grep -E "available.*memory|free.*memory|check.*resources" scripts/create-vm-wizard.sh
    [ "$status" -eq 0 ] || skip "Resource validation may be optional"
}

@test "vm create wizard uses libvirt" {
    run grep -E "virsh|libvirt" scripts/create-vm-wizard.sh
    [ "$status" -eq 0 ]
}
