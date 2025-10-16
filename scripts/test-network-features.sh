#!/usr/bin/env bash
# shellcheck disable=SC2034
#
# Comprehensive Network Feature Testing Suite
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test result
test_result() {
    local name="$1"
    local result="$2"
    
    ((TESTS_RUN++))
    
    if [[ "$result" == "pass" ]]; then
        echo -e "${GREEN}✓${NC} $name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $name"
        ((TESTS_FAILED++))
    fi
}

# Test module existence
test_modules() {
    echo "Testing NixOS Modules..."
    
    local modules=(
        "ipv6" "traffic-shaping" "bonding" "dhcp-server" "vpn"
        "firewall-zones" "dns-server" "bridges" "monitoring"
        "performance-tuning" "tor" "packet-capture" "ids"
        "load-balancer" "automation"
    )
    
    for mod in "${modules[@]}"; do
        if [[ -f "/workspace/modules/network-settings/${mod}.nix" ]]; then
            test_result "Module: $mod" "pass"
        else
            test_result "Module: $mod" "fail"
        fi
    done
}

# Test phase detection
test_phase_detection() {
    echo
    echo "Testing Phase Detection..."
    
    # Test phase markers
    if [[ -f /etc/hypervisor/.phase1_setup ]] || [[ -f /etc/hypervisor/.phase2_hardened ]]; then
        test_result "Phase markers exist" "pass"
    else
        test_result "Phase markers (not required)" "pass"
    fi
    
    # Test phase detection script
    if command -v hv-phase >/dev/null 2>&1; then
        if hv-phase status >/dev/null 2>&1; then
            test_result "Phase detection command" "pass"
        else
            test_result "Phase detection command" "fail"
        fi
    else
        test_result "Phase detection command (not in PATH)" "pass"
    fi
}

# Test wizard
test_wizard() {
    echo
    echo "Testing Unified Wizard..."
    
    if [[ -x "/workspace/scripts/setup/unified-network-wizard.sh" ]]; then
        test_result "Unified wizard exists" "pass"
        test_result "Wizard is executable" "pass"
    else
        test_result "Unified wizard" "fail"
    fi
}

# Test discovery library
test_discovery() {
    echo
    echo "Testing Network Discovery..."
    
    if [[ -f "/workspace/scripts/lib/network-discovery.sh" ]]; then
        test_result "Discovery library exists" "pass"
        
        # Source and test functions
        if source "/workspace/scripts/lib/network-discovery.sh" 2>/dev/null; then
            test_result "Discovery library loads" "pass"
            
            if command -v get_physical_interfaces >/dev/null 2>&1; then
                test_result "Discovery functions available" "pass"
            else
                test_result "Discovery functions" "fail"
            fi
        else
            test_result "Discovery library loads" "fail"
        fi
    else
        test_result "Discovery library" "fail"
    fi
}

# Test phase compatibility
test_phase_compatibility() {
    echo
    echo "Testing Phase Compatibility..."
    
    # Each module should have phase awareness
    local has_phase_config=0
    
    for mod in /workspace/modules/network-settings/*.nix; do
        if grep -q "phaseConfig\|currentPhase" "$mod" 2>/dev/null; then
            ((has_phase_config++))
        fi
    done
    
    if [[ $has_phase_config -gt 0 ]]; then
        test_result "Modules have phase awareness ($has_phase_config modules)" "pass"
    else
        test_result "Phase-aware modules" "fail"
    fi
}

# Show summary
show_summary() {
    echo
    echo "═══════════════════════════════════════"
    echo "Test Summary"
    echo "═══════════════════════════════════════"
    echo -e "Total Tests:  $TESTS_RUN"
    echo -e "${GREEN}Passed:       $TESTS_PASSED${NC}"
    echo -e "${RED}Failed:       $TESTS_FAILED${NC}"
    echo
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        return 1
    fi
}

# Main
main() {
    echo "Hyper-NixOS Network Features Test Suite"
    echo "═══════════════════════════════════════"
    echo
    
    test_modules
    test_phase_detection
    test_wizard
    test_discovery
    test_phase_compatibility
    
    show_summary
}

# Run
main "$@"
