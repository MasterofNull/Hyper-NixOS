#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Hyper-NixOS First Boot Menu
# Simple welcome screen that provides information and launches setup wizard
#

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Configuration
readonly FIRST_BOOT_FLAG="/var/lib/hypervisor/.first-boot-complete"
readonly SETUP_COMPLETE_FLAG="/var/lib/hypervisor/.setup-complete"

# Clear screen and show welcome
show_welcome() {
    clear
    cat << EOF
${CYAN}
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║        ${BOLD}Welcome to Hyper-NixOS${NC}${CYAN}                                 ║
║        ${BOLD}Next-Generation Virtualization Platform${NC}${CYAN}              ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
${NC}

${GREEN}✓ Installation Complete!${NC}

Your Hyper-NixOS system has been successfully installed with:
  • ${BOLD}Users & Passwords${NC}: Migrated from your host system
  • ${BOLD}Hardware Configuration${NC}: Automatically detected and configured
  • ${BOLD}Base System${NC}: Minimal configuration with essential tools

${BLUE}═══════════════════════════════════════════════════════════════${NC}

${BOLD}What's Next?${NC}

This is your ${YELLOW}base configuration${NC}. You're now ready to customize your
system by selecting a configuration tier that matches your needs.

${BOLD}Available Tiers:${NC}

  ${GREEN}1. Minimal${NC}      - Basic VM management (2GB RAM minimum)
                   Perfect for learning and testing

  ${GREEN}2. Standard${NC}     - Common features (4GB RAM recommended)
                   Good for home labs and development

  ${GREEN}3. Enhanced${NC}     - Advanced features (8GB RAM recommended)
                   Full-featured VM platform

  ${GREEN}4. Professional${NC} - Enterprise features (16GB RAM recommended)
                   Production-ready with monitoring

  ${GREEN}5. Enterprise${NC}   - All features enabled (32GB RAM recommended)
                   Maximum capabilities

${BLUE}═══════════════════════════════════════════════════════════════${NC}

EOF
}

# Show system status
show_status() {
    local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local system_ram=$((mem_kb / 1024))  # Convert to MB
    local system_cpus=$(nproc)
    local system_disk=$(df -BG /nix/store | tail -1 | awk '{print $4}' | sed 's/G//')
    
    echo -e "${BOLD}Current System:${NC}"
    echo -e "  • RAM: ${GREEN}${system_ram} MB${NC}"
    echo -e "  • CPUs: ${GREEN}${system_cpus} cores${NC}"
    echo -e "  • Available Disk: ${GREEN}${system_disk} GB${NC}"
    echo
}

# Show recommended tier
recommend_tier() {
    local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local system_ram=$((mem_kb / 1024))
    local system_cpus=$(nproc)
    
    local recommended="standard"
    
    if [[ $system_ram -ge 32768 ]] && [[ $system_cpus -ge 16 ]]; then
        recommended="enterprise"
    elif [[ $system_ram -ge 16384 ]] && [[ $system_cpus -ge 8 ]]; then
        recommended="professional"
    elif [[ $system_ram -ge 8192 ]] && [[ $system_cpus -ge 4 ]]; then
        recommended="enhanced"
    elif [[ $system_ram -ge 4096 ]]; then
        recommended="standard"
    else
        recommended="minimal"
    fi
    
    echo -e "${BOLD}Recommended for your hardware:${NC} ${YELLOW}${recommended}${NC}"
    echo
}

# Show menu options
show_menu() {
    echo -e "${BOLD}Choose an option:${NC}"
    echo
    echo "  1) Launch System Setup Wizard (configure tier)"
    echo "  2) View system information"
    echo "  3) Read documentation"
    echo "  4) Skip for now (configure later)"
    echo "  5) Exit to shell"
    echo
}

# Main menu loop
main() {
    # Check if we should run
    if [[ -f "$SETUP_COMPLETE_FLAG" ]]; then
        echo -e "${GREEN}System setup is already complete!${NC}"
        echo
        echo "Your system is configured and ready to use."
        echo
        echo "To reconfigure, run: ${BOLD}sudo system-setup-wizard${NC}"
        echo
        read -p "Press Enter to continue..."
        exit 0
    fi
    
    # Show welcome screen
    show_welcome
    show_status
    recommend_tier
    
    while true; do
        show_menu
        read -p "Enter your choice [1-5]: " choice
        echo
        
        case $choice in
            1)
                echo -e "${GREEN}Launching System Setup Wizard...${NC}"
                echo
                
                # Check if wizard exists
                if command -v system-setup-wizard >/dev/null 2>&1; then
                    exec system-setup-wizard
                elif [[ -x /etc/hypervisor/bin/system-setup-wizard ]]; then
                    exec /etc/hypervisor/bin/system-setup-wizard
                else
                    echo -e "${RED}Error: Setup wizard not found!${NC}"
                    echo "Please run: sudo nixos-rebuild switch"
                    read -p "Press Enter to continue..."
                fi
                ;;
            2)
                clear
                echo -e "${CYAN}${BOLD}System Information${NC}\n"
                show_status
                echo -e "${BOLD}Detected Hardware:${NC}"
                echo
                lscpu | grep -E "^Model name|^CPU\(s\)|^Thread|^Core"
                echo
                lspci | grep -E "VGA|3D|Ethernet" | head -5
                echo
                df -h / /nix/store 2>/dev/null || df -h /
                echo
                read -p "Press Enter to continue..."
                clear
                show_welcome
                ;;
            3)
                clear
                echo -e "${CYAN}${BOLD}Documentation${NC}\n"
                echo "Documentation is available at:"
                echo "  • /etc/hypervisor/docs/"
                echo "  • https://github.com/MasterofNull/Hyper-NixOS"
                echo
                echo "Key documents:"
                echo "  • Quick Start: /etc/hypervisor/docs/QUICK_START.md"
                echo "  • Installation Guide: /etc/hypervisor/docs/INSTALLATION_GUIDE.md"
                echo "  • Feature Catalog: /etc/hypervisor/docs/FEATURE_CATALOG.md"
                echo
                read -p "Press Enter to continue..."
                clear
                show_welcome
                ;;
            4)
                echo -e "${YELLOW}Setup skipped.${NC}"
                echo
                echo "You can configure your system later by running:"
                echo "  ${BOLD}sudo system-setup-wizard${NC}"
                echo
                echo "Or from the first-boot menu:"
                echo "  ${BOLD}first-boot-menu${NC}"
                echo
                
                # Create flag to prevent auto-run on next boot
                mkdir -p "$(dirname "$FIRST_BOOT_FLAG")"
                touch "$FIRST_BOOT_FLAG"
                
                read -p "Press Enter to continue to shell..."
                exit 0
                ;;
            5)
                echo -e "${GREEN}Exiting to shell...${NC}"
                echo
                echo "Welcome to Hyper-NixOS!"
                echo "Run ${BOLD}first-boot-menu${NC} anytime to return to this menu."
                echo
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please enter 1-5.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Run main menu
main "$@"
