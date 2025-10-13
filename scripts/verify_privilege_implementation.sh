#!/usr/bin/env bash
#
# Verify Privilege Implementation
# Sudo Required: NO (for checks), YES (for fixes)
#
# Copyright (c) 2025 Hyper-NixOS Contributors
# License: MIT
#
# This script verifies that the privilege separation model is correctly implemented
#

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/exit_codes.sh"

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# Check result function
check_result() {
    local check_name="$1"
    local result="$2"
    local details="${3:-}"
    
    case "$result" in
        PASS)
            echo -e "${GREEN}✓${NC} $check_name"
            CHECKS_PASSED=$((CHECKS_PASSED + 1))
            ;;
        FAIL)
            echo -e "${RED}✗${NC} $check_name"
            if [[ -n "$details" ]]; then
                echo "  └─ $details"
            fi
            CHECKS_FAILED=$((CHECKS_FAILED + 1))
            ;;
        WARN)
            echo -e "${YELLOW}⚠${NC} $check_name"
            if [[ -n "$details" ]]; then
                echo "  └─ $details"
            fi
            CHECKS_WARNING=$((CHECKS_WARNING + 1))
            ;;
        INFO)
            echo -e "${BLUE}ℹ${NC} $check_name"
            if [[ -n "$details" ]]; then
                echo "  └─ $details"
            fi
            ;;
    esac
}

# Print header
print_header() {
    cat <<EOF
╔═══════════════════════════════════════════════════════════════╗
║        Privilege Implementation Verification                  ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  This script verifies that privilege separation is correctly  ║
║  implemented across all components.                           ║
║                                                               ║
║  User: $(get_actual_user)
║  Running as sudo: $(is_running_as_sudo && echo "YES" || echo "NO")
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

EOF
}

# Check 1: Core library functions
check_core_library() {
    echo "=== Checking Core Library Functions ==="
    
    # Check if functions exist
    local functions=(
        "check_sudo_requirement"
        "check_vm_group_membership"
        "get_actual_user"
        "is_running_as_sudo"
        "operation_requires_sudo"
        "show_sudo_warning"
    )
    
    local all_exist=true
    for func in "${functions[@]}"; do
        if type -t "$func" &>/dev/null; then
            check_result "Function $func exists" "PASS"
        else
            check_result "Function $func exists" "FAIL" "Function not found"
            all_exist=false
        fi
    done
    
    echo
}

# Check 2: Script metadata
check_script_metadata() {
    echo "=== Checking Script Metadata ==="
    
    # Check VM scripts don't require sudo
    local vm_scripts=(
        "vm_start.sh"
        "vm_stop.sh"
        "menu/menu.sh"
        "menu/lib/vm_operations.sh"
    )
    
    for script in "${vm_scripts[@]}"; do
        if [[ -f "$SCRIPT_DIR/$script" ]]; then
            if grep -q "Sudo Required: NO" "$SCRIPT_DIR/$script"; then
                check_result "$script marked as no-sudo" "PASS"
            else
                check_result "$script marked as no-sudo" "FAIL" "Missing or incorrect sudo requirement"
            fi
        else
            check_result "$script exists" "WARN" "Script not found"
        fi
    done
    
    # Check system scripts require sudo
    local sys_scripts=(
        "system_config.sh"
        "examples/system_config_sudo.sh"
    )
    
    for script in "${sys_scripts[@]}"; do
        if [[ -f "$SCRIPT_DIR/$script" ]]; then
            if grep -q "Sudo Required: YES" "$SCRIPT_DIR/$script"; then
                check_result "$script marked as requiring sudo" "PASS"
            else
                check_result "$script marked as requiring sudo" "FAIL" "Missing sudo requirement"
            fi
        else
            check_result "$script exists" "WARN" "Script not found"
        fi
    done
    
    echo
}

# Check 3: User groups
check_user_groups() {
    echo "=== Checking User Groups ==="
    
    local current_user=$(get_actual_user)
    check_result "Current user detected" "INFO" "$current_user"
    
    # Check libvirtd group
    if groups | grep -q '\blibvirtd\b'; then
        check_result "User in libvirtd group" "PASS"
    else
        check_result "User in libvirtd group" "FAIL" "Run: sudo usermod -aG libvirtd $current_user"
    fi
    
    # Check kvm group
    if groups | grep -q '\bkvm\b'; then
        check_result "User in kvm group" "PASS"
    else
        check_result "User in kvm group" "WARN" "Recommended: sudo usermod -aG kvm $current_user"
    fi
    
    # Check hypervisor groups if they exist
    for group in hypervisor-users hypervisor-operators hypervisor-admins; do
        if getent group "$group" &>/dev/null; then
            if groups | grep -q "\b$group\b"; then
                check_result "User in $group" "INFO" "Member"
            else
                check_result "User in $group" "INFO" "Not a member"
            fi
        fi
    done
    
    echo
}

# Check 4: Polkit rules
check_polkit_rules() {
    echo "=== Checking Polkit Rules ==="
    
    local polkit_dir="/etc/polkit-1/rules.d"
    
    if [[ -d "$polkit_dir" ]]; then
        local hypervisor_rules=$(find "$polkit_dir" -name "*hypervisor*.rules" 2>/dev/null | wc -l)
        
        if [[ $hypervisor_rules -gt 0 ]]; then
            check_result "Polkit rules installed" "PASS" "Found $hypervisor_rules rule files"
            
            # List rule files
            find "$polkit_dir" -name "*hypervisor*.rules" -exec basename {} \; | while read -r rule; do
                check_result "  Rule: $rule" "INFO"
            done
        else
            check_result "Polkit rules installed" "FAIL" "No hypervisor polkit rules found"
        fi
    else
        check_result "Polkit directory exists" "FAIL" "Polkit may not be installed"
    fi
    
    echo
}

# Check 5: File permissions
check_file_permissions() {
    echo "=== Checking File Permissions ==="
    
    # VM directories (should be accessible)
    local vm_dirs=(
        "/var/lib/hypervisor/vms"
        "/var/lib/hypervisor/backups"
        "/var/lib/hypervisor/snapshots"
        "/var/lib/libvirt/images"
    )
    
    for dir in "${vm_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            if [[ -r "$dir" ]] && [[ -w "$dir" ]]; then
                check_result "$dir accessible" "PASS"
            elif [[ -r "$dir" ]]; then
                check_result "$dir accessible" "WARN" "Read-only access"
            else
                check_result "$dir accessible" "FAIL" "No access"
            fi
        else
            check_result "$dir exists" "INFO" "Directory not found"
        fi
    done
    
    # System directories (should be protected)
    local sys_dirs=(
        "/etc/hypervisor"
        "/var/lib/hypervisor/system"
    )
    
    for dir in "${sys_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            if [[ -w "$dir" ]] && ! is_running_as_sudo; then
                check_result "$dir protected" "FAIL" "Writable without sudo"
            else
                check_result "$dir protected" "PASS"
            fi
        else
            check_result "$dir exists" "INFO" "Directory not found"
        fi
    done
    
    echo
}

# Check 6: VM operations
check_vm_operations() {
    echo "=== Checking VM Operations ==="
    
    # Try to list VMs without sudo
    if virsh --connect qemu:///system list --all &>/dev/null; then
        check_result "List VMs without sudo" "PASS"
        
        # Count VMs
        local vm_count=$(virsh --connect qemu:///system list --all --name | grep -v '^$' | wc -l)
        check_result "VM count" "INFO" "$vm_count VMs found"
    else
        check_result "List VMs without sudo" "FAIL" "Cannot connect to libvirt"
    fi
    
    # Check libvirt socket
    if [[ -S /var/run/libvirt/libvirt-sock ]]; then
        if [[ -r /var/run/libvirt/libvirt-sock ]] && [[ -w /var/run/libvirt/libvirt-sock ]]; then
            check_result "Libvirt socket accessible" "PASS"
        else
            check_result "Libvirt socket accessible" "FAIL" "Check socket permissions"
        fi
    else
        check_result "Libvirt socket exists" "FAIL" "Socket not found"
    fi
    
    echo
}

# Check 7: Documentation
check_documentation() {
    echo "=== Checking Documentation ==="
    
    local docs=(
        "docs/dev/PRIVILEGE_SEPARATION_MODEL.md"
        "docs/SCRIPT_PRIVILEGE_CLASSIFICATION.md"
        "docs/USER_SETUP_GUIDE.md"
    )
    
    for doc in "${docs[@]}"; do
        if [[ -f "$SCRIPT_DIR/../$doc" ]]; then
            check_result "$(basename "$doc") exists" "PASS"
        else
            check_result "$(basename "$doc") exists" "FAIL" "Documentation missing"
        fi
    done
    
    echo
}

# Check 8: NixOS modules
check_nixos_modules() {
    echo "=== Checking NixOS Modules ==="
    
    local modules=(
        "modules/security/privilege-separation.nix"
        "modules/security/polkit-rules.nix"
    )
    
    for module in "${modules[@]}"; do
        if [[ -f "$SCRIPT_DIR/../$module" ]]; then
            check_result "$(basename "$module") exists" "PASS"
        else
            check_result "$(basename "$module") exists" "FAIL" "Module missing"
        fi
    done
    
    echo
}

# Print summary
print_summary() {
    local total=$((CHECKS_PASSED + CHECKS_FAILED + CHECKS_WARNING))
    
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Verification Summary"
    echo "═══════════════════════════════════════════════════════════════"
    echo
    echo "  Total checks: $total"
    echo -e "  Passed: ${GREEN}$CHECKS_PASSED${NC}"
    echo -e "  Failed: ${RED}$CHECKS_FAILED${NC}"
    echo -e "  Warnings: ${YELLOW}$CHECKS_WARNING${NC}"
    echo
    
    if [[ $CHECKS_FAILED -eq 0 ]]; then
        echo -e "  ${GREEN}✓ Privilege separation is properly implemented!${NC}"
    else
        echo -e "  ${RED}✗ Some issues need to be addressed${NC}"
        echo
        echo "  Common fixes:"
        echo "  1. Add user to libvirtd group: sudo usermod -aG libvirtd,kvm $USER"
        echo "  2. Install polkit rules: sudo nixos-rebuild switch"
        echo "  3. Check script permissions: chmod +x scripts/*.sh"
    fi
    
    echo
}

# Main execution
main() {
    print_header
    
    check_core_library
    check_script_metadata
    check_user_groups
    check_polkit_rules
    check_file_permissions
    check_vm_operations
    check_documentation
    check_nixos_modules
    
    print_summary
    
    if [[ $CHECKS_FAILED -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

main "$@"