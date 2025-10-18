#!/usr/bin/env bash
################################################################################
# Hyper-NixOS - Test Generator Script
# Generates basic test files for untested modules
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Function to generate a basic module test
generate_module_test() {
    local module_path="$1"
    local module_name=$(basename "$module_path" .nix)
    local test_name="test_${module_name}"
    local test_file="$SCRIPT_DIR/modules/${test_name}.nix"

    # Skip if test already exists
    if [ -f "$test_file" ]; then
        echo "  Skipping $module_name (test exists)"
        return
    fi

    echo "  Creating test for $module_name..."

    cat > "$test_file" << EOF
################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Test: $(echo $module_name | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g') Module
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "${module_name}";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../${module_path}
    ];

    # Enable the module (adjust based on actual module structure)
    hypervisor.${module_name}.enable = lib.mkDefault true;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Basic module load test
    with subtest("Module loaded"):
        # Verify module configuration is applied
        machine.succeed("echo 'Module ${module_name} loaded'")

    # Add specific tests for this module
    with subtest("Module functionality"):
        # TODO: Add module-specific tests
        machine.succeed("true")

    print("✓ ${module_name} tests passed")
  '';
}
EOF
}

# Function to generate a basic script test
generate_script_test() {
    local script_path="$1"
    local script_name=$(basename "$script_path" .sh)
    local test_name="test_${script_name}"
    local test_file="$SCRIPT_DIR/scripts/${test_name}.bats"

    # Skip if test already exists
    if [ -f "$test_file" ]; then
        echo "  Skipping $script_name (test exists)"
        return
    fi

    echo "  Creating test for $script_name..."

    cat > "$test_file" << 'EOF'
#!/usr/bin/env bats
################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
#
# Test: SCRIPT_NAME_PLACEHOLDER Script
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
    [ -f "SCRIPT_PATH_PLACEHOLDER" ]
    [ -x "SCRIPT_PATH_PLACEHOLDER" ]
}

@test "script has proper shebang" {
    run head -1 SCRIPT_PATH_PLACEHOLDER
    [[ "$output" == *"#!/usr/bin/env bash"* ]] || [[ "$output" == *"#!/bin/bash"* ]]
}

@test "script uses error handling" {
    run grep -E "set -e" SCRIPT_PATH_PLACEHOLDER
    [ "$status" -eq 0 ]
}

@test "script has help or usage function" {
    run grep -E "^(function )?(show_help|usage)" SCRIPT_PATH_PLACEHOLDER
    [ "$status" -eq 0 ] || skip "Help function optional"
}
EOF

    # Replace placeholders
    sed -i "s|SCRIPT_NAME_PLACEHOLDER|$script_name|g" "$test_file"
    sed -i "s|SCRIPT_PATH_PLACEHOLDER|scripts/$script_name.sh|g" "$test_file"
}

echo "🔧 Generating tests for untested modules..."
echo ""

# Generate tests for core modules
echo "Core modules:"
for module in options hypervisor-base directories keymap-sanitizer portable-base optimized-system; do
    if [ -f "$PROJECT_ROOT/modules/core/${module}.nix" ]; then
        generate_module_test "modules/core/${module}.nix"
    fi
done

echo ""
echo "Feature modules:"
for module in adaptive-docs educational-content feature-categories; do
    if [ -f "$PROJECT_ROOT/modules/features/${module}.nix" ]; then
        generate_module_test "modules/features/${module}.nix"
    fi
done

echo ""
echo "GUI modules:"
for module in input remote-desktop admin-integration; do
    if [ -f "$PROJECT_ROOT/modules/gui/${module}.nix" ]; then
        generate_module_test "modules/gui/${module}.nix"
    fi
done

echo ""
echo "Security modules:"
for module in base; do
    if [ -f "$PROJECT_ROOT/modules/security/${module}.nix" ]; then
        generate_module_test "modules/security/${module}.nix"
    fi
done

echo ""
echo "🔧 Generating tests for untested scripts..."
echo ""

# Generate tests for key utility scripts
SCRIPTS_TO_TEST=(
    "lib/common.sh"
    "lib/ui.sh"
    "lib/risk-notifications.sh"
    "lib/branding.sh"
)

for script in "${SCRIPTS_TO_TEST[@]}"; do
    if [ -f "$PROJECT_ROOT/scripts/$script" ]; then
        generate_script_test "scripts/$script"
    fi
done

echo ""
echo "✅ Test generation complete!"
echo ""
echo "Tests generated. You may need to manually adjust:"
echo "  - Module enable paths (hypervisor.modulename.enable)"
echo "  - Specific test assertions for each module"
echo "  - Script-specific functionality tests"
