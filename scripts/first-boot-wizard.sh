#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Hyper-NixOS First Boot Configuration Wizard
# This script runs on first boot to help users select their system configuration
#

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/ui.sh"

# Initialize script
init_script "$(basename "$0")"

set -euo pipefail

# Colors for UI
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Configuration
readonly CONFIG_FILE="/etc/nixos/configuration/configuration.nix"
readonly TIER_CONFIG="/etc/nixos/hypervisor-tier.nix"
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

# Display welcome message
show_welcome() {
    clear
    cat << EOF
${CYAN}
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║        ${BOLD}Welcome to Hyper-NixOS First Boot Setup${NC}${CYAN}              ║
║                                                               ║
║  This wizard will help you configure your system based on     ║
║  your hardware resources and intended use case.               ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
${NC}

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

${BLUE}Use Cases:${NC}
  • Home labs with limited resources
  • Development environments
  • Learning virtualization
  • Single-purpose VM hosts

${MAGENTA}System Impact:${NC}
  • RAM Usage: ~500MB base
  • Disk Usage: ~2GB installation
  • Very lightweight
EOF
            ;;
            
        standard)
            cat << EOF
${BOLD}Virtualization + Monitoring + Basic Security${NC}

${GREEN}Features (includes all from Minimal plus):${NC}
  • Prometheus monitoring stack
  • Grafana dashboards
  • Basic security hardening
  • NFTables firewall
  • SSH hardening
  • Audit logging
  • Basic backup tools

${YELLOW}Services:${NC}
  • All minimal services plus:
  • prometheus - Metrics collection
  • grafana - Visualization
  • node-exporter - System metrics
  • auditd - Security auditing

${BLUE}Use Cases:${NC}
  • Small business virtualization
  • Monitoring-enabled home labs
  • Security-conscious deployments
  • Multi-VM environments

${MAGENTA}System Impact:${NC}
  • RAM Usage: ~1-2GB base
  • Disk Usage: ~5GB installation
  • Moderate resource usage
EOF
            ;;
            
        enhanced)
            cat << EOF
${BOLD}Advanced Features + Desktop Environment${NC}

${GREEN}Features (includes all from Standard plus):${NC}
  • Full desktop environment (KDE/GNOME)
  • Web-based management dashboard
  • Advanced networking (bridges, VLANs)
  • Storage management (LVM, ZFS)
  • VM templates library
  • Container support (Podman/Docker)
  • Automated snapshots

${YELLOW}Services:${NC}
  • All standard services plus:
  • Display manager (GUI)
  • hypervisor-api - REST API
  • hypervisor-web - Web UI
  • podman - Container runtime

${BLUE}Use Cases:${NC}
  • Desktop virtualization
  • Development workstations
  • Small IT departments
  • Mixed VM/container environments

${MAGENTA}System Impact:${NC}
  • RAM Usage: ~3-4GB base
  • Disk Usage: ~15GB installation
  • Requires GPU for desktop
EOF
            ;;
            
        professional)
            cat << EOF
${BOLD}AI-Powered Security + Full Automation${NC}

${GREEN}Features (includes all from Enhanced plus):${NC}
  • AI/ML threat detection
  • Behavioral analysis for zero-day protection
  • Automated threat response
  • Full automation suite
  • Performance auto-tuning
  • Multi-host management
  • Secret management (Vault)
  • Infrastructure as Code

${YELLOW}Services:${NC}
  • All enhanced services plus:
  • hypervisor-ml-detector - ML engine
  • hypervisor-threat-analyzer - Analysis
  • hypervisor-automation - Automation
  • vault - Secret management
  • consul - Service discovery

${BLUE}Use Cases:${NC}
  • Security-focused deployments
  • DevOps environments
  • Automated infrastructure
  • Advanced threat protection

${MAGENTA}System Impact:${NC}
  • RAM Usage: ~6-8GB base
  • Disk Usage: ~25GB installation
  • GPU required for ML acceleration
EOF
            ;;
            
        enterprise)
            cat << EOF
${BOLD}Full Enterprise Platform with Clustering${NC}

${GREEN}Features (includes all from Professional plus):${NC}
  • Multi-node clustering
  • High availability configurations
  • Distributed storage (Ceph/GlusterFS)
  • Enterprise backup solutions
  • Compliance and reporting tools
  • Multi-tenant isolation
  • Identity federation (Keycloak)
  • Elasticsearch/Kibana stack

${YELLOW}Services:${NC}
  • All professional services plus:
  • corosync/pacemaker - HA clustering
  • ceph - Distributed storage
  • elasticsearch - Search/analytics
  • kibana - Data visualization
  • keycloak - Identity management

${BLUE}Use Cases:${NC}
  • Large organizations
  • Service providers
  • High-availability requirements
  • Compliance-driven environments

${MAGENTA}System Impact:${NC}
  • RAM Usage: ~12-16GB base
  • Disk Usage: ~50GB installation
  • Requires 3+ nodes for HA
  • GPU required
EOF
            ;;
    esac
    
    echo -e "\n\nPress ${BOLD}Enter${NC} to return to selection..."
    read -r
}

# Tier selection menu
select_tier() {
    local selected_tier=""
    
    while [[ -z $selected_tier ]]; do
        clear
        echo -e "${CYAN}${BOLD}Select Your System Configuration Tier${NC}\n"
        
        show_tier_info "minimal" "Core Virtualization Platform" "$BLUE"
        show_tier_info "standard" "Virtualization + Monitoring + Basic Security" "$GREEN"
        show_tier_info "enhanced" "Advanced Features + Desktop Environment" "$YELLOW"
        show_tier_info "professional" "AI-Powered Security + Full Automation" "$MAGENTA"
        show_tier_info "enterprise" "Full Enterprise Platform with Clustering" "$RED"
        
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo
        echo -e "Enter tier name for details, or type '${BOLD}select <tier>${NC}' to choose:"
        echo -e "Example: ${BOLD}minimal${NC} (for details) or ${BOLD}select minimal${NC} (to choose)"
        echo
        read -r -p "> " choice
        
        case $choice in
            minimal|standard|enhanced|professional|enterprise)
                show_tier_details "$choice"
                ;;
            "select minimal"|"select standard"|"select enhanced"|"select professional"|"select enterprise")
                selected_tier=$(echo "$choice" | cut -d' ' -f2)
                ;;
            *)
                echo -e "${RED}Invalid choice. Press Enter to continue...${NC}"
                read -r
                ;;
        esac
    done
    
    echo "$selected_tier"
}

# Generate tier configuration
generate_tier_config() {
    local tier=$1
    
    cat > "$TIER_CONFIG" << EOF
# Hyper-NixOS Tier Configuration
# Generated by first-boot wizard on $(date)
# Selected tier: $tier

{ config, lib, pkgs, ... }:

{
  # Set the system tier
  hypervisor.systemTier = "$tier";
  
  # The actual features will be enabled based on this tier
  # See modules/system-tiers.nix for tier definitions
}
EOF
}

# Update main configuration to use minimal + tier
update_main_config() {
    # Backup current configuration
    cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Create new minimal configuration that imports tier
    cat > "$CONFIG_FILE" << 'EOF'
# Hyper-NixOS Configuration
# This minimal configuration imports the selected tier configuration

{ config, lib, pkgs, ... }:

{
  imports = [
    # Hardware configuration (generated by nixos-generate-config)
    ./hardware-configuration.nix
    
    # System tier configuration (selected during first boot)
    ./hypervisor-tier.nix
    
    # Core system modules (always needed)
    ./modules/core/system.nix
    ./modules/core/packages.nix
    ./modules/core/directories.nix
    ./modules/core/first-boot.nix
    
    # System tiers definition
    ./modules/system-tiers.nix
    
    # Feature manager (reads tier and enables appropriate features)
    ./modules/features/feature-manager.nix
  ];

  # System identification
  networking.hostName = "hyper-nixos";
  system.stateVersion = "24.05";
  
  # Boot configuration (minimal)
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };
    
    # Basic virtualization kernel parameters
    kernelParams = [ 
      "intel_iommu=on"
      "amd_iommu=on"
      "iommu=pt"
    ];
  };
  
  # Enable hypervisor
  hypervisor.enable = true;
  
  # Basic networking
  networking = {
    networkmanager.enable = true;
    firewall.enable = true;
  };
  
  # Basic user
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "libvirtd" "kvm" ];
    initialPassword = "changeme";
  };
  
  # Enable sudo
  security.sudo.wheelNeedsPassword = true;
  
  # Basic system packages (additional packages added by tier)
  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    htop
  ];
}
EOF
}

# Apply configuration
apply_configuration() {
    local tier=$1
    
    echo -e "\n${CYAN}${BOLD}Applying Configuration...${NC}\n"
    
    # Show what will be done
    echo -e "${YELLOW}The following actions will be performed:${NC}"
    echo -e "  1. Generate tier configuration for: ${BOLD}$tier${NC}"
    echo -e "  2. Update system configuration to minimal + tier"
    echo -e "  3. Rebuild NixOS with new configuration"
    echo -e "  4. Enable required services"
    echo
    echo -e "${YELLOW}${BOLD}Warning:${NC} This will rebuild your system configuration."
    echo -e "Current configuration will be backed up."
    echo
    read -r -p "Continue? (y/N): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${RED}Configuration cancelled.${NC}"
        return 1
    fi
    
    # Generate configurations
    echo -e "\n${BLUE}Generating tier configuration...${NC}"
    generate_tier_config "$tier"
    
    echo -e "${BLUE}Updating main configuration...${NC}"
    update_main_config
    
    # Test configuration
    echo -e "\n${BLUE}Testing configuration...${NC}"
    if nixos-rebuild dry-build; then
        echo -e "${GREEN}✓ Configuration is valid${NC}"
    else
        echo -e "${RED}✗ Configuration test failed${NC}"
        echo -e "${YELLOW}Restoring backup...${NC}"
        cp "${CONFIG_FILE}.backup."* "$CONFIG_FILE"
        return 1
    fi
    
    # Apply configuration
    echo -e "\n${BLUE}Applying configuration (this may take a while)...${NC}"
    if nixos-rebuild switch; then
        echo -e "${GREEN}✓ Configuration applied successfully!${NC}"
        
        # Mark first boot as complete
        mkdir -p "$(dirname "$FIRST_BOOT_FLAG")"
        touch "$FIRST_BOOT_FLAG"
        
        return 0
    else
        echo -e "${RED}✗ Configuration failed${NC}"
        echo -e "${YELLOW}Restoring backup...${NC}"
        cp "${CONFIG_FILE}.backup."* "$CONFIG_FILE"
        return 1
    fi
}

# Show next steps
show_next_steps() {
    local tier=$1
    
    clear
    echo -e "${GREEN}${BOLD}Configuration Complete!${NC}\n"
    
    echo -e "${CYAN}Your Hyper-NixOS system is now configured with the ${BOLD}$tier${NC}${CYAN} tier.${NC}\n"
    
    echo -e "${BOLD}Next Steps:${NC}"
    echo -e "  1. ${BOLD}Change default password:${NC} passwd admin"
    echo -e "  2. ${BOLD}Check system status:${NC} systemctl status hypervisor-*"
    echo -e "  3. ${BOLD}View available commands:${NC} hv help"
    
    case $tier in
        minimal)
            echo -e "  4. ${BOLD}Create your first VM:${NC} hv vm create"
            ;;
        standard|enhanced)
            echo -e "  4. ${BOLD}Access monitoring:${NC} http://localhost:3000 (Grafana)"
            echo -e "  5. ${BOLD}Create your first VM:${NC} hv vm create"
            ;;
        professional|enterprise)
            echo -e "  4. ${BOLD}Access web dashboard:${NC} http://localhost:8080"
            echo -e "  5. ${BOLD}View AI security status:${NC} hv security status"
            echo -e "  6. ${BOLD}Configure automation:${NC} hv automation setup"
            ;;
    esac
    
    echo -e "\n${BOLD}Documentation:${NC}"
    echo -e "  • Quick Start: ${BLUE}/usr/share/doc/hypervisor/QUICK_START.md${NC}"
    echo -e "  • User Guide: ${BLUE}/usr/share/doc/hypervisor/USER_GUIDE.md${NC}"
    echo -e "  • Admin Guide: ${BLUE}/usr/share/doc/hypervisor/ADMIN_GUIDE.md${NC}"
    
    if [[ $tier == "professional" ]] || [[ $tier == "enterprise" ]]; then
        echo -e "  • AI Features: ${BLUE}/usr/share/doc/hypervisor/AI_FEATURES_GUIDE.md${NC}"
    fi
    
    echo -e "\n${GREEN}Enjoy your Hyper-NixOS system!${NC}"
}

# Main function
main() {
    # Check if running as root
check_root
        echo -e "${RED}This script must be run as root${NC}"
        exit 1
    
    # Check if first boot was already completed
    if [[ -f "$FIRST_BOOT_FLAG" ]]; then
        echo -e "${YELLOW}First boot configuration has already been completed.${NC}"
        echo -e "To reconfigure, remove: $FIRST_BOOT_FLAG"
        exit 0
    fi
    
    # Detect system resources
    detect_system_resources
    
    # Show welcome
    show_welcome
    
    # Select tier
    SELECTED_TIER=$(select_tier)
    
    # Confirm selection
    clear
    echo -e "${CYAN}${BOLD}Confirm Your Selection${NC}\n"
    echo -e "You have selected: ${BOLD}${SELECTED_TIER}${NC}"
    echo
    show_tier_details "$SELECTED_TIER" | head -20
    echo
    read -r -p "Is this correct? (y/N): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Restarting selection...${NC}"
        sleep 2
        exec "$0"
    fi
    
    # Apply configuration
    if apply_configuration "$SELECTED_TIER"; then
        show_next_steps "$SELECTED_TIER"
    else
        echo -e "\n${RED}Configuration failed. Please check the logs and try again.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"
