#!/usr/bin/env bash
# System Requirements Validator
# Checks all dependencies before running wizards
# Part of Design Ethos - Ease of Use (Pillar 1)

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Track issues
MISSING_DEPS=()
WARNINGS=()
PASSED=0
FAILED=0

check_command() {
    local cmd=$1
    local required=${2:-yes}
    local description=$3
    
    if command -v "$cmd" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $cmd - $description"
        ((PASSED++))
        return 0
    else
        if [ "$required" = "yes" ]; then
            echo -e "${RED}✗${NC} $cmd - $description ${RED}(REQUIRED)${NC}"
            MISSING_DEPS+=("$cmd")
            ((FAILED++))
        else
            echo -e "${YELLOW}⚠${NC} $cmd - $description ${YELLOW}(OPTIONAL)${NC}"
            WARNINGS+=("$cmd - $description")
        fi
        return 1
    fi
}

check_file() {
    local file=$1
    local description=$2
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $file - $description"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $file - $description ${RED}(MISSING)${NC}"
        ((FAILED++))
        return 1
    fi
}

check_directory() {
    local dir=$1
    local create=${2:-no}
    local description=$3
    
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓${NC} $dir - $description"
        ((PASSED++))
        return 0
    else
        if [ "$create" = "yes" ] && [ -w "$(dirname "$dir")" ]; then
            mkdir -p "$dir"
            echo -e "${BLUE}✓${NC} $dir - $description ${BLUE}(CREATED)${NC}"
            ((PASSED++))
            return 0
        else
            echo -e "${RED}✗${NC} $dir - $description ${RED}(MISSING)${NC}"
            ((FAILED++))
            return 1
        fi
    fi
}

main() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗"
    echo -e "║  ${BOLD}System Requirements Validation${NC}${BLUE}                       "
    echo -e "╚════════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${YELLOW}Checking core dependencies...${NC}\n"
    
    # Core shell tools
    check_command bash yes "Bash shell"
    check_command jq yes "JSON processor for configs"
    check_command awk yes "Text processing"
    check_command sed yes "Stream editor"
    check_command grep yes "Pattern matching"
    
    echo ""
    echo -e "${YELLOW}Checking system tools...${NC}\n"
    
    # System information tools
    check_command nproc yes "CPU core detection"
    check_command lscpu yes "CPU information"
    check_command lspci no "PCI device detection"
    check_command lsblk yes "Block device detection"
    check_command ip yes "Network configuration"
    check_command ss yes "Socket statistics"
    check_command df yes "Disk space detection"
    check_command free yes "Memory detection"
    
    echo ""
    echo -e "${YELLOW}Checking virtualization tools...${NC}\n"
    
    # Virtualization
    check_command virsh yes "Libvirt management"
    check_command qemu-system-x86_64 no "QEMU virtualization"
    check_command systemctl yes "Service management"
    
    echo ""
    echo -e "${YELLOW}Checking network tools...${NC}\n"
    
    # Network
    check_command bridge no "Bridge utilities"
    check_command iptables no "Firewall management"
    
    echo ""
    echo -e "${YELLOW}Checking dialog tools...${NC}\n"
    
    # UI tools
    check_command whiptail no "Dialog interface (fallback: dialog)"
    check_command dialog no "Dialog interface (fallback: whiptail)"
    
    if ! command -v whiptail &> /dev/null && ! command -v dialog &> /dev/null; then
        echo -e "${YELLOW}⚠${NC} No dialog tool found - wizards will use basic prompts"
        WARNINGS+=("dialog/whiptail - Enhanced UI for wizards")
    fi
    
    echo ""
    echo -e "${YELLOW}Checking Hyper-NixOS files...${NC}\n"
    
    # Core scripts
    check_file "/workspace/scripts/lib/system_discovery.sh" "System discovery library"
    check_file "/workspace/scripts/lib/intelligent_template_processor.sh" "Template processor"
    check_file "/workspace/scripts/hv" "Unified CLI"
    check_file "/workspace/scripts/hv-intelligent-defaults" "Defaults demo tool"
    
    echo ""
    echo -e "${YELLOW}Checking wizard files...${NC}\n"
    
    check_file "/workspace/scripts/create_vm_wizard.sh" "VM creation wizard"
    check_file "/workspace/scripts/first-boot-wizard.sh" "First-boot wizard"
    check_file "/workspace/scripts/security-configuration-wizard.sh" "Security wizard"
    check_file "/workspace/scripts/network-configuration-wizard.sh" "Network wizard"
    check_file "/workspace/scripts/backup-configuration-wizard.sh" "Backup wizard"
    check_file "/workspace/scripts/storage-configuration-wizard.sh" "Storage wizard"
    check_file "/workspace/scripts/monitoring-configuration-wizard.sh" "Monitoring wizard"
    
    echo ""
    echo -e "${YELLOW}Checking directories...${NC}\n"
    
    # Directories (with auto-create)
    check_directory "/var/lib/hypervisor" yes "Hypervisor state directory"
    check_directory "/var/lib/hypervisor/logs" yes "Log directory"
    check_directory "/var/lib/hypervisor/vm_profiles" yes "VM profiles directory"
    check_directory "/etc/hypervisor" yes "Configuration directory"
    
    # Results
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}Validation Results:${NC}"
    echo -e "  ${GREEN}Passed:${NC} $PASSED"
    echo -e "  ${RED}Failed:${NC} $FAILED"
    echo -e "  ${YELLOW}Warnings:${NC} ${#WARNINGS[@]}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    
    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        echo ""
        echo -e "${RED}${BOLD}Missing Required Dependencies:${NC}"
        for dep in "${MISSING_DEPS[@]}"; do
            echo -e "  ${RED}✗${NC} $dep"
        done
        echo ""
        echo -e "${YELLOW}Installation suggestions:${NC}"
        echo -e "  NixOS: Add missing packages to configuration.nix"
        echo -e "  Other: Use your package manager (apt, yum, pacman, etc.)"
        echo ""
        exit 1
    fi
    
    if [ ${#WARNINGS[@]} -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}${BOLD}Optional Improvements:${NC}"
        for warn in "${WARNINGS[@]}"; do
            echo -e "  ${YELLOW}⚠${NC} $warn"
        done
        echo ""
        echo -e "${BLUE}These are optional but recommended for best experience${NC}"
        echo ""
    fi
    
    echo -e "${GREEN}${BOLD}✓ System is ready for Hyper-NixOS wizards!${NC}"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo -e "  1. Run: ${BOLD}hv discover${NC} to see system detection"
    echo -e "  2. Run: ${BOLD}hv defaults-demo${NC} for interactive demo"
    echo -e "  3. Run: ${BOLD}hv vm-create${NC} to create your first VM"
    echo ""
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
