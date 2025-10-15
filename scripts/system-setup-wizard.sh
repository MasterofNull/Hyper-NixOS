#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Hyper-NixOS System Setup Wizard
# Handles tier selection and final system configuration
#

set -euo pipefail

# Source shared libraries if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
[[ -f "${SCRIPT_DIR}/lib/common.sh" ]] && source "${SCRIPT_DIR}/lib/common.sh" || true

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Configuration
readonly CONFIG_FILE="/etc/nixos/configuration.nix"
readonly SETUP_COMPLETE_FLAG="/var/lib/hypervisor/.setup-complete"
readonly FIRST_BOOT_FLAG="/var/lib/hypervisor/.first-boot-complete"

# System requirements (in MB for RAM)
declare -A MIN_RAM=(
    ["minimal"]=2048
    ["standard"]=4096
    ["enhanced"]=8192
    ["professional"]=16384
    ["enterprise"]=32768
)

declare -A REC_RAM=(
    ["minimal"]=4096
    ["standard"]=8192
    ["enhanced"]=16384
    ["professional"]=32768
    ["enterprise"]=65536
)

declare -A MIN_CPUS=(
    ["minimal"]=2
    ["standard"]=2
    ["enhanced"]=4
    ["professional"]=8
    ["enterprise"]=16
)

# Detect system resources
detect_system_resources() {
    local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    SYSTEM_RAM=$((mem_kb / 1024))  # Convert to MB
    SYSTEM_CPUS=$(nproc)
    
    # Detect GPU
    if lspci | grep -E "(VGA|3D)" | grep -iE "(nvidia|amd|intel)" > /dev/null; then
        SYSTEM_GPU="available"
    else
        SYSTEM_GPU="none"
    fi
    
    # Detect available disk space
    SYSTEM_DISK=$(df -BG /nix/store | tail -1 | awk '{print $4}' | sed 's/G//')
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root!${NC}"
        echo "Please run: sudo system-setup-wizard"
        exit 1
    fi
}

# Display welcome message for setup wizard
show_setup_welcome() {
    clear
    cat << EOF
${CYAN}
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║        ${BOLD}Hyper-NixOS System Setup Wizard${NC}${CYAN}                      ║
║        ${BOLD}Configure Your Virtualization Platform${NC}${CYAN}               ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
${NC}

This wizard will help you configure your Hyper-NixOS system by
selecting an appropriate tier based on your hardware and needs.

${BOLD}System Resources Detected:${NC}
  • RAM: ${GREEN}${SYSTEM_RAM} MB${NC}
  • CPUs: ${GREEN}${SYSTEM_CPUS} cores${NC}
  • GPU: ${GREEN}${SYSTEM_GPU}${NC}
  • Available Disk: ${GREEN}${SYSTEM_DISK} GB${NC}

Press ${BOLD}Enter${NC} to continue...
EOF
    read -r
}

# Display tier information
show_tier_info() {
    local tier=$1
    local description=$2
    local min_ram=${MIN_RAM[$tier]}
    local rec_ram=${REC_RAM[$tier]}
    local min_cpus=${MIN_CPUS[$tier]}
    local color=$3
    
    echo -e "${color}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${color}${BOLD}$tier${NC} - $description"
    echo -e "  Requirements: RAM: ${min_ram}MB (min) / ${rec_ram}MB (rec) | CPUs: ${min_cpus}+"
    
    # Check if system meets requirements
    if [[ $SYSTEM_RAM -ge $rec_ram ]] && [[ $SYSTEM_CPUS -ge $min_cpus ]]; then
        echo -e "  ${GREEN}✓ Recommended for your system${NC}"
    elif [[ $SYSTEM_RAM -ge $min_ram ]] && [[ $SYSTEM_CPUS -ge $min_cpus ]]; then
        echo -e "  ${YELLOW}⚠ Meets minimum requirements${NC}"
    else
        echo -e "  ${RED}✗ Below minimum requirements${NC}"
    fi
}

# Show tier details
show_tier_details() {
    local tier=$1
    
    clear
    echo -e "${CYAN}${BOLD}Configuration Tier: ${tier^^}${NC}\n"
    
    case $tier in
        minimal)
            cat << EOF
${BOLD}Core Virtualization Platform${NC}

${GREEN}Features:${NC}
  • Basic VM management with libvirt/QEMU
  • Command-line tools (virsh, virt-install)
  • NAT networking for VMs
  • Basic console management tools
  • Minimal resource usage

${YELLOW}Services:${NC}
  • libvirtd - VM management daemon
  • virtlogd - VM logging service
  • Basic networking (virbr0)

${BLUE}Use Cases:${NC}
  • Home labs with limited resources
  • Development environments
  • Learning virtualization
  • Testing and experimentation

${BOLD}Resources:${NC}
  • Minimum: 2GB RAM, 2 CPUs
  • Recommended: 4GB RAM, 2+ CPUs
EOF
            ;;
        standard)
            cat << EOF
${BOLD}Enhanced Virtualization with GUI${NC}

${GREEN}Features:${NC}
  • Everything in Minimal tier
  • Web dashboard for management
  • Virt-manager GUI application
  • Basic monitoring (Prometheus)
  • Automated health checks
  • ISO management tools

${YELLOW}Services:${NC}
  • Web dashboard on port 8080
  • Prometheus metrics
  • Automated health monitoring
  • Resource tracking

${BLUE}Use Cases:${NC}
  • Home labs and development
  • Small production deployments
  • GUI-based management preference
  • Basic monitoring needs

${BOLD}Resources:${NC}
  • Minimum: 4GB RAM, 2 CPUs
  • Recommended: 8GB RAM, 4+ CPUs
EOF
            ;;
        enhanced)
            cat << EOF
${BOLD}Advanced Features and Automation${NC}

${GREEN}Features:${NC}
  • Everything in Standard tier
  • Automated backups
  • Snapshot management
  • Advanced networking (VLANs, bridges)
  • Grafana dashboards
  • Email alerts
  • Storage optimization

${YELLOW}Services:${NC}
  • Automated backup service
  • Grafana visualization
  • Alert manager
  • Storage deduplication
  • Network isolation

${BLUE}Use Cases:${NC}
  • Production environments
  • Multi-VM deployments
  • Automated management needs
  • Advanced networking requirements

${BOLD}Resources:${NC}
  • Minimum: 8GB RAM, 4 CPUs
  • Recommended: 16GB RAM, 6+ CPUs
EOF
            ;;
        professional)
            cat << EOF
${BOLD}Enterprise-Grade Platform${NC}

${GREEN}Features:${NC}
  • Everything in Enhanced tier
  • High availability clustering
  • GPU passthrough support
  • Advanced security (AppArmor, SELinux)
  • Resource quotas
  • VFIO/PCIe passthrough
  • Live migration

${YELLOW}Services:${NC}
  • Cluster management
  • GPU virtualization
  • Advanced security modules
  • Audit logging
  • Performance profiling

${BLUE}Use Cases:${NC}
  • Production clusters
  • GPU-accelerated workloads
  • High-security environments
  • Enterprise deployments

${BOLD}Resources:${NC}
  • Minimum: 16GB RAM, 8 CPUs
  • Recommended: 32GB RAM, 12+ CPUs
EOF
            ;;
        enterprise)
            cat << EOF
${BOLD}Maximum Feature Set${NC}

${GREEN}Features:${NC}
  • Everything in Professional tier
  • AI-driven monitoring and optimization
  • Automated remediation
  • Advanced threat detection
  • Multi-site replication
  • Zero-trust security
  • Complete automation suite
  • Tag-based compute units
  • Heat-map storage tiers

${YELLOW}Services:${NC}
  • AI anomaly detection
  • Automated response system
  • Distributed storage
  • GraphQL API
  • Advanced orchestration
  • Comprehensive logging

${BLUE}Use Cases:${NC}
  • Large-scale deployments
  • Mission-critical workloads
  • Maximum automation needs
  • Advanced features exploration

${BOLD}Resources:${NC}
  • Minimum: 32GB RAM, 16 CPUs
  • Recommended: 64GB+ RAM, 24+ CPUs
EOF
            ;;
    esac
    
    echo
}

# Show all available tiers
show_all_tiers() {
    clear
    echo -e "${CYAN}${BOLD}Available Configuration Tiers${NC}\n"
    
    show_tier_info "minimal" "Core virtualization platform" "$GREEN"
    echo
    show_tier_info "standard" "Enhanced with GUI and monitoring" "$BLUE"
    echo
    show_tier_info "enhanced" "Advanced features and automation" "$MAGENTA"
    echo
    show_tier_info "professional" "Enterprise-grade platform" "$YELLOW"
    echo
    show_tier_info "enterprise" "Maximum feature set" "$RED"
    echo
}

# Get tier selection
select_tier() {
    while true; do
        show_all_tiers
        
        echo -e "${BOLD}Select your system tier:${NC}"
        echo "  1) Minimal"
        echo "  2) Standard"
        echo "  3) Enhanced"
        echo "  4) Professional"
        echo "  5) Enterprise"
        echo "  i) Show detailed information for a tier"
        echo "  q) Quit without changes"
        echo
        read -p "Enter choice: " choice
        
        case $choice in
            1) SELECTED_TIER="minimal"; break ;;
            2) SELECTED_TIER="standard"; break ;;
            3) SELECTED_TIER="enhanced"; break ;;
            4) SELECTED_TIER="professional"; break ;;
            5) SELECTED_TIER="enterprise"; break ;;
            i|I)
                echo
                read -p "Enter tier number to view details [1-5]: " detail_choice
                case $detail_choice in
                    1) show_tier_details "minimal"; read -p "Press Enter to continue..." ;;
                    2) show_tier_details "standard"; read -p "Press Enter to continue..." ;;
                    3) show_tier_details "enhanced"; read -p "Press Enter to continue..." ;;
                    4) show_tier_details "professional"; read -p "Press Enter to continue..." ;;
                    5) show_tier_details "enterprise"; read -p "Press Enter to continue..." ;;
                    *) echo -e "${RED}Invalid choice${NC}"; sleep 1 ;;
                esac
                ;;
            q|Q)
                echo
                echo -e "${YELLOW}Setup cancelled.${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please enter 1-5, i, or q.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Confirm selection
confirm_selection() {
    clear
    show_tier_details "$SELECTED_TIER"
    
    echo
    echo -e "${YELLOW}${BOLD}Confirm Configuration${NC}"
    echo
    echo -e "You have selected: ${GREEN}${BOLD}${SELECTED_TIER}${NC}"
    echo
    echo "This will configure your system with the selected tier."
    echo "The system will rebuild and may take a few minutes."
    echo
    read -p "Proceed with this configuration? (yes/no): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo -e "${YELLOW}Configuration cancelled. Returning to tier selection...${NC}"
        sleep 2
        return 1
    fi
    
    return 0
}

# Apply configuration
apply_configuration() {
    echo
    echo -e "${BLUE}${BOLD}Applying Configuration...${NC}"
    echo
    
    # Create new configuration
    cat > "$CONFIG_FILE.new" <<EOF
# Hyper-NixOS Configuration
# Generated by System Setup Wizard on $(date)
# Selected Tier: $SELECTED_TIER

{ config, lib, pkgs, ... }:

{
  imports = [
    # Import the base minimal configuration
    /etc/nixos/profiles/configuration-minimal.nix
    # Import the tier system
    /etc/nixos/modules/system-tiers.nix
  ];
  
  # Set the selected tier
  hypervisor.systemTier = "$SELECTED_TIER";
  
  # Disable first boot wizard (setup is complete)
  hypervisor.firstBoot.autoStart = false;
}
EOF
    
    # Backup original and apply new config
    if [[ -f "$CONFIG_FILE" ]]; then
        cp "$CONFIG_FILE" "$CONFIG_FILE.backup-$(date +%Y%m%d-%H%M%S)"
        echo -e "${GREEN}✓${NC} Original configuration backed up"
    fi
    
    mv "$CONFIG_FILE.new" "$CONFIG_FILE"
    echo -e "${GREEN}✓${NC} Configuration file updated"
    echo
    
    # Rebuild the system
    echo -e "${YELLOW}Building new system configuration...${NC}"
    echo "This may take several minutes depending on your tier selection."
    echo
    
    if nixos-rebuild switch; then
        echo
        echo -e "${GREEN}${BOLD}✓ System rebuild successful!${NC}"
        
        # Mark setup as complete
        mkdir -p "$(dirname "$SETUP_COMPLETE_FLAG")"
        touch "$SETUP_COMPLETE_FLAG"
        touch "$FIRST_BOOT_FLAG"
        
        return 0
    else
        echo
        echo -e "${RED}${BOLD}✗ System rebuild failed!${NC}"
        echo
        echo "Restoring backup configuration..."
        
        if [[ -f "$CONFIG_FILE.backup-$(date +%Y%m%d-%H%M%S)" ]]; then
            cp "$CONFIG_FILE.backup-$(date +%Y%m%d-%H%M%S)" "$CONFIG_FILE"
            echo -e "${GREEN}✓${NC} Original configuration restored"
        fi
        
        return 1
    fi
}

# Show completion message
show_completion() {
    clear
    cat << EOF
${GREEN}
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║        ${BOLD}System Setup Complete!${NC}${GREEN}                              ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
${NC}

${BOLD}Your Hyper-NixOS system is now configured with the ${YELLOW}${SELECTED_TIER}${NC}${BOLD} tier.${NC}

${GREEN}What's Available:${NC}

  • VM Management: Use ${BOLD}virt-manager${NC} or ${BOLD}virsh${NC} commands
  • Menu System: Run ${BOLD}hypervisor-menu${NC} for interactive management
  • Documentation: Available in ${BOLD}/etc/hypervisor/docs/${NC}

EOF

    case $SELECTED_TIER in
        standard|enhanced|professional|enterprise)
            echo -e "  • Web Dashboard: ${BOLD}http://$(hostname -I | awk '{print $1}'):8080${NC}"
            ;;
    esac
    
    case $SELECTED_TIER in
        enhanced|professional|enterprise)
            echo -e "  • Grafana: ${BOLD}http://$(hostname -I | awk '{print $1}'):3000${NC}"
            echo -e "  • Prometheus: ${BOLD}http://$(hostname -I | awk '{print $1}'):9090${NC}"
            ;;
    esac
    
    echo
    echo -e "${BOLD}Next Steps:${NC}"
    echo "  1. Create your first VM: ${BOLD}virt-manager${NC} or ${BOLD}hypervisor-menu${NC}"
    echo "  2. Review documentation: ${BOLD}less /etc/hypervisor/docs/QUICK_START.md${NC}"
    echo "  3. Configure networking: ${BOLD}hypervisor-menu${NC} → Network Setup"
    echo
    echo -e "${CYAN}To reconfigure your tier later, run: ${BOLD}sudo system-setup-wizard${NC}"
    echo
    echo "Press ${BOLD}Enter${NC} to continue..."
    read -r
}

# Main function
main() {
    # Check prerequisites
    check_root
    detect_system_resources
    
    # Show welcome
    show_setup_welcome
    
    # Select tier
    select_tier
    
    # Confirm and apply
    while ! confirm_selection; do
        select_tier
    done
    
    # Apply configuration
    if apply_configuration; then
        show_completion
    else
        echo
        echo -e "${RED}Setup failed. Please check the errors above and try again.${NC}"
        echo
        read -p "Press Enter to exit..."
        exit 1
    fi
}

# Run main
main "$@"
