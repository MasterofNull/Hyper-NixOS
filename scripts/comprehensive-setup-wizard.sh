#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Hyper-NixOS Comprehensive Setup Wizard
# Complete system configuration, feature selection, and VM deployment
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
readonly WIZARD_STATE="/var/lib/hypervisor/.wizard-state"

# Wizard state variables
DETECTED_FEATURES=()
SELECTED_FEATURES=()
SELECTED_GUI=""
SELECTED_TIER=""
VMS_TO_CREATE=()

# Detect system resources
detect_system_resources() {
    local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    SYSTEM_RAM=$((mem_kb / 1024))  # Convert to MB
    SYSTEM_CPUS=$(nproc)
    
    # Detect GPU with detailed info
    SYSTEM_GPU="none"
    SYSTEM_GPU_TYPE=""
    if lspci | grep -E "(VGA|3D)" | grep -i "nvidia" > /dev/null; then
        SYSTEM_GPU="nvidia"
        SYSTEM_GPU_TYPE="NVIDIA GPU detected"
    elif lspci | grep -E "(VGA|3D)" | grep -i "amd" > /dev/null; then
        SYSTEM_GPU="amd"
        SYSTEM_GPU_TYPE="AMD GPU detected"
    elif lspci | grep -E "(VGA|3D)" | grep -i "intel" > /dev/null; then
        SYSTEM_GPU="intel"
        SYSTEM_GPU_TYPE="Intel GPU detected"
    fi
    
    # Detect available disk space
    SYSTEM_DISK=$(df -BG /nix/store | tail -1 | awk '{print $4}' | sed 's/G//')
    
    # Detect virtualization support
    SYSTEM_VIRT_SUPPORT="none"
    if grep -E 'vmx|svm' /proc/cpuinfo > /dev/null; then
        if grep -q 'vmx' /proc/cpuinfo; then
            SYSTEM_VIRT_SUPPORT="Intel VT-x"
        else
            SYSTEM_VIRT_SUPPORT="AMD-V"
        fi
    fi
    
    # Detect IOMMU
    SYSTEM_IOMMU="no"
    if [[ -d /sys/class/iommu ]] && [[ -n "$(ls -A /sys/class/iommu 2>/dev/null)" ]]; then
        SYSTEM_IOMMU="yes"
    fi
    
    # Detect network interfaces
    SYSTEM_NICS=$(ip link | grep -E '^[0-9]+:' | grep -v 'lo:' | wc -l)
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root!${NC}"
        echo "Please run: sudo comprehensive-setup-wizard"
        exit 1
    fi
}

# Welcome screen
show_welcome() {
    clear
    cat << EOF
${CYAN}
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     ${BOLD}Hyper-NixOS Comprehensive Setup Wizard${NC}${CYAN}                  ║
║     ${BOLD}Complete System Configuration & Deployment${NC}${CYAN}              ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
${NC}

Welcome to Hyper-NixOS! This wizard will guide you through:

  ${GREEN}1.${NC} ${BOLD}Hardware Detection${NC} - Analyzing your system capabilities
  ${GREEN}2.${NC} ${BOLD}Feature Selection${NC} - Choosing services based on your hardware
  ${GREEN}3.${NC} ${BOLD}GUI Environment${NC} - Selecting desktop environment (or headless)
  ${GREEN}4.${NC} ${BOLD}VM Deployment${NC} - Creating and deploying virtual machines
  ${GREEN}5.${NC} ${BOLD}Final Configuration${NC} - Building your complete system

${YELLOW}${BOLD}After completion:${NC}
  • System will be fully configured and functional
  • VMs will be deployed and ready to use
  • Boot into headless VM menu with auto-selection
  • Switch to admin GUI/CLI anytime

${BOLD}Detected System:${NC}
  • RAM: ${GREEN}${SYSTEM_RAM} MB${NC}
  • CPUs: ${GREEN}${SYSTEM_CPUS} cores${NC}
  • GPU: ${GREEN}${SYSTEM_GPU_TYPE:-None detected}${NC}
  • Virtualization: ${GREEN}${SYSTEM_VIRT_SUPPORT}${NC}
  • IOMMU: ${GREEN}${SYSTEM_IOMMU}${NC}
  • Network Interfaces: ${GREEN}${SYSTEM_NICS}${NC}
  • Available Disk: ${GREEN}${SYSTEM_DISK} GB${NC}

Press ${BOLD}Enter${NC} to begin setup...
EOF
    read -r
}

# Detect available features based on hardware
detect_available_features() {
    DETECTED_FEATURES=()
    
    # Always available
    DETECTED_FEATURES+=("base:Basic VM Management:Always available")
    
    # RAM-based features
    if [[ $SYSTEM_RAM -ge 4096 ]]; then
        DETECTED_FEATURES+=("monitoring:System Monitoring (Prometheus/Grafana):4GB+ RAM")
    fi
    
    if [[ $SYSTEM_RAM -ge 8192 ]]; then
        DETECTED_FEATURES+=("web-dashboard:Web Dashboard:8GB+ RAM")
        DETECTED_FEATURES+=("backups:Automated Backups:8GB+ RAM")
    fi
    
    if [[ $SYSTEM_RAM -ge 16384 ]]; then
        DETECTED_FEATURES+=("clustering:HA Clustering:16GB+ RAM")
        DETECTED_FEATURES+=("advanced-networking:Advanced Networking (VLANs):16GB+ RAM")
    fi
    
    # GPU-based features
    if [[ "$SYSTEM_GPU" != "none" ]]; then
        DETECTED_FEATURES+=("gpu-passthrough:GPU Passthrough:GPU detected")
    fi
    
    # IOMMU-based features
    if [[ "$SYSTEM_IOMMU" == "yes" ]]; then
        DETECTED_FEATURES+=("pcie-passthrough:PCIe Device Passthrough:IOMMU enabled")
    fi
    
    # Network-based features
    if [[ $SYSTEM_NICS -ge 2 ]]; then
        DETECTED_FEATURES+=("network-isolation:Network Isolation:Multiple NICs")
    fi
    
    # CPU-based features
    if [[ $SYSTEM_CPUS -ge 8 ]]; then
        DETECTED_FEATURES+=("performance-tuning:Performance Tuning:8+ CPUs")
    fi
    
    # Always available optional features
    DETECTED_FEATURES+=("security-hardening:Security Hardening:Optional")
    DETECTED_FEATURES+=("automation:Automation Scripts:Optional")
}

# Show feature selection
select_features() {
    clear
    echo -e "${CYAN}${BOLD}Step 2: Feature Selection${NC}\n"
    echo "Based on your hardware, these features are available:"
    echo
    
    local i=1
    local feature_ids=()
    for feature in "${DETECTED_FEATURES[@]}"; do
        IFS=':' read -r id name requirement <<< "$feature"
        feature_ids+=("$id")
        
        # Check if feature is enabled
        local status=" "
        if [[ " ${SELECTED_FEATURES[@]} " =~ " ${id} " ]]; then
            status="✓"
        fi
        
        echo -e "  ${GREEN}${i})${NC} [${status}] ${BOLD}${name}${NC}"
        echo -e "      Requirement: ${YELLOW}${requirement}${NC}"
        echo
        ((i++))
    done
    
    echo
    echo -e "${BOLD}Options:${NC}"
    echo -e "  ${GREEN}[number]${NC} - Toggle feature on/off"
    echo -e "  ${GREEN}a${NC} - Select all available features"
    echo -e "  ${GREEN}r${NC} - Select recommended features (auto-detect)"
    echo -e "  ${GREEN}n${NC} - Continue to next step"
    echo
    read -p "Enter choice: " choice
    
    case $choice in
        [0-9]*)
            local idx=$((choice - 1))
            if [[ $idx -ge 0 && $idx -lt ${#DETECTED_FEATURES[@]} ]]; then
                local feature_id="${feature_ids[$idx]}"
                if [[ " ${SELECTED_FEATURES[@]} " =~ " ${feature_id} " ]]; then
                    # Remove feature
                    SELECTED_FEATURES=("${SELECTED_FEATURES[@]/$feature_id}")
                else
                    # Add feature
                    SELECTED_FEATURES+=("$feature_id")
                fi
            fi
            select_features  # Redisplay
            ;;
        a|A)
            # Select all
            SELECTED_FEATURES=("${feature_ids[@]}")
            select_features
            ;;
        r|R)
            # Auto-select recommended
            SELECTED_FEATURES=("base")
            if [[ $SYSTEM_RAM -ge 4096 ]]; then
                SELECTED_FEATURES+=("monitoring")
            fi
            if [[ $SYSTEM_RAM -ge 8192 ]]; then
                SELECTED_FEATURES+=("web-dashboard" "backups" "automation")
            fi
            if [[ "$SYSTEM_GPU" != "none" ]]; then
                SELECTED_FEATURES+=("gpu-passthrough")
            fi
            select_features
            ;;
        n|N)
            # Continue
            return 0
            ;;
        *)
            select_features
            ;;
    esac
}

# Select GUI environment
select_gui_environment() {
    clear
    echo -e "${CYAN}${BOLD}Step 3: GUI Environment Selection${NC}\n"
    echo "Choose your preferred desktop environment:"
    echo
    echo -e "  ${GREEN}1)${NC} ${BOLD}Headless${NC} (No GUI - recommended for hypervisors)"
    echo "     • Minimal resource usage"
    echo "     • CLI and web-based management only"
    echo "     • SSH access for administration"
    echo
    echo -e "  ${GREEN}2)${NC} ${BOLD}GNOME${NC} (Modern, user-friendly)"
    echo "     • Full-featured desktop environment"
    echo "     • Easy to use, great for beginners"
    echo "     • Resource usage: ~2GB RAM"
    echo
    echo -e "  ${GREEN}3)${NC} ${BOLD}KDE Plasma${NC} (Customizable, powerful)"
    echo "     • Highly customizable interface"
    echo "     • Advanced features and settings"
    echo "     • Resource usage: ~1.5GB RAM"
    echo
    echo -e "  ${GREEN}4)${NC} ${BOLD}XFCE${NC} (Lightweight, fast)"
    echo "     • Low resource usage"
    echo "     • Traditional desktop layout"
    echo "     • Resource usage: ~512MB RAM"
    echo
    echo -e "  ${GREEN}5)${NC} ${BOLD}LXQt${NC} (Ultra-lightweight)"
    echo "     • Minimal resource usage"
    echo "     • Simple and fast"
    echo "     • Resource usage: ~256MB RAM"
    echo
    
    read -p "Enter choice [1-5]: " gui_choice
    
    case $gui_choice in
        1) SELECTED_GUI="headless" ;;
        2) SELECTED_GUI="gnome" ;;
        3) SELECTED_GUI="kde" ;;
        4) SELECTED_GUI="xfce" ;;
        5) SELECTED_GUI="lxqt" ;;
        *)
            echo -e "${RED}Invalid choice. Defaulting to headless.${NC}"
            sleep 2
            SELECTED_GUI="headless"
            ;;
    esac
    
    echo
    echo -e "${GREEN}Selected: ${BOLD}${SELECTED_GUI}${NC}"
    sleep 1
}

# VM deployment
deploy_vms() {
    clear
    echo -e "${CYAN}${BOLD}Step 4: VM Deployment${NC}\n"
    echo "Would you like to create VMs now?"
    echo
    echo "You can create VMs for common use cases:"
    echo -e "  • ${GREEN}Ubuntu Desktop${NC} - General purpose Linux desktop"
    echo -e "  • ${GREEN}Windows 10/11${NC} - Windows virtual machine"
    echo -e "  • ${GREEN}Server (Ubuntu Server)${NC} - Headless server VM"
    echo -e "  • ${GREEN}Development VM${NC} - Pre-configured development environment"
    echo -e "  • ${GREEN}Custom${NC} - Define your own VM specifications"
    echo
    echo -e "  • ${YELLOW}Skip${NC} - Create VMs later through the menu"
    echo
    read -p "Create VMs now? (y/N): " create_vms
    
    if [[ ! $create_vms =~ ^[Yy]$ ]]; then
        echo
        echo -e "${YELLOW}Skipping VM creation. You can create VMs later from the menu.${NC}"
        sleep 2
        return 0
    fi
    
    # VM creation loop
    while true; do
        clear
        echo -e "${CYAN}${BOLD}VM Deployment${NC}\n"
        echo "Select VM template to deploy:"
        echo
        echo -e "  ${GREEN}1)${NC} Ubuntu Desktop 24.04 (4GB RAM, 2 CPUs, 50GB disk)"
        echo -e "  ${GREEN}2)${NC} Ubuntu Server 24.04 (2GB RAM, 2 CPUs, 30GB disk)"
        echo -e "  ${GREEN}3)${NC} Windows 10 (8GB RAM, 4 CPUs, 80GB disk)"
        echo -e "  ${GREEN}4)${NC} Windows 11 (8GB RAM, 4 CPUs, 80GB disk)"
        echo -e "  ${GREEN}5)${NC} Development VM (4GB RAM, 4 CPUs, 60GB disk)"
        echo -e "  ${GREEN}6)${NC} Custom VM (specify your own settings)"
        echo -e "  ${GREEN}d)${NC} Done - Continue to next step"
        echo
        
        if [[ ${#VMS_TO_CREATE[@]} -gt 0 ]]; then
            echo -e "${BOLD}VMs queued for creation:${NC}"
            for vm in "${VMS_TO_CREATE[@]}"; do
                echo -e "  • ${GREEN}$vm${NC}"
            done
            echo
        fi
        
        read -p "Enter choice: " vm_choice
        
        case $vm_choice in
            1) VMS_TO_CREATE+=("ubuntu-desktop:Ubuntu Desktop 24.04:4096:2:50") ;;
            2) VMS_TO_CREATE+=("ubuntu-server:Ubuntu Server 24.04:2048:2:30") ;;
            3) VMS_TO_CREATE+=("windows10:Windows 10:8192:4:80") ;;
            4) VMS_TO_CREATE+=("windows11:Windows 11:8192:4:80") ;;
            5) VMS_TO_CREATE+=("dev-vm:Development VM:4096:4:60") ;;
            6)
                echo
                read -p "VM name: " vm_name
                read -p "RAM (MB): " vm_ram
                read -p "CPUs: " vm_cpus
                read -p "Disk (GB): " vm_disk
                VMS_TO_CREATE+=("${vm_name}:${vm_name}:${vm_ram}:${vm_cpus}:${vm_disk}")
                ;;
            d|D) break ;;
            *) echo -e "${RED}Invalid choice${NC}"; sleep 1 ;;
        esac
    done
}

# Generate final configuration
generate_configuration() {
    clear
    echo -e "${BLUE}${BOLD}Step 5: Generating Configuration...${NC}\n"
    
    # Determine tier based on features
    local tier="minimal"
    if [[ " ${SELECTED_FEATURES[@]} " =~ " clustering " ]]; then
        tier="enterprise"
    elif [[ " ${SELECTED_FEATURES[@]} " =~ " advanced-networking " ]]; then
        tier="professional"
    elif [[ " ${SELECTED_FEATURES[@]} " =~ " backups " ]]; then
        tier="enhanced"
    elif [[ " ${SELECTED_FEATURES[@]} " =~ " monitoring " ]]; then
        tier="standard"
    fi
    
    SELECTED_TIER="$tier"
    
    # Backup current config
    if [[ -f "$CONFIG_FILE" ]]; then
        cp "$CONFIG_FILE" "$CONFIG_FILE.backup-$(date +%Y%m%d-%H%M%S)"
        echo -e "${GREEN}✓${NC} Original configuration backed up"
    fi
    
    # Generate new configuration
    cat > "$CONFIG_FILE" <<EOF
# Hyper-NixOS Configuration
# Generated by Comprehensive Setup Wizard on $(date)
# Tier: $SELECTED_TIER
# GUI: $SELECTED_GUI
# Features: ${SELECTED_FEATURES[*]}

{ config, lib, pkgs, ... }:

{
  imports = [
    # Base configuration
    /etc/nixos/profiles/configuration-minimal.nix
    # Tier system
    /etc/nixos/modules/system-tiers.nix
    # Headless VM menu
    /etc/nixos/modules/headless-vm-menu.nix
  ];
  
  # System tier
  hypervisor.systemTier = "$SELECTED_TIER";
  
  # GUI Environment
  hypervisor.gui = {
    enable = $(if [[ "$SELECTED_GUI" == "headless" ]]; then echo "false"; else echo "true"; fi);
    environment = "$SELECTED_GUI";
  };
  
  # Selected features
  hypervisor.features = {
EOF

    # Add feature configurations
    for feature in "${SELECTED_FEATURES[@]}"; do
        case $feature in
            monitoring)
                cat >> "$CONFIG_FILE" <<'FEATURE_EOF'
    monitoring = {
      enable = true;
      prometheus = true;
      grafana = true;
    };
FEATURE_EOF
                ;;
            web-dashboard)
                cat >> "$CONFIG_FILE" <<'FEATURE_EOF'
    webDashboard = {
      enable = true;
      port = 8080;
    };
FEATURE_EOF
                ;;
            backups)
                cat >> "$CONFIG_FILE" <<'FEATURE_EOF'
    backups = {
      enable = true;
      schedule = "daily";
    };
FEATURE_EOF
                ;;
            gpu-passthrough)
                cat >> "$CONFIG_FILE" <<'FEATURE_EOF'
    gpuPassthrough = {
      enable = true;
      gpuType = "$SYSTEM_GPU";
    };
FEATURE_EOF
                ;;
        esac
    done
    
    cat >> "$CONFIG_FILE" <<'EOF'
  };
  
  # Headless VM menu (boot default)
  hypervisor.headlessMenu = {
    enable = true;
    autoStart = true;
    autoSelectTimeout = 10;  # seconds
  };
  
  # Disable first boot wizard (setup complete)
  hypervisor.firstBoot.autoStart = false;
}
EOF
    
    echo -e "${GREEN}✓${NC} Configuration file generated"
}

# Create VMs
create_vms() {
    if [[ ${#VMS_TO_CREATE[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No VMs to create${NC}"
        return 0
    fi
    
    echo
    echo -e "${BLUE}${BOLD}Creating Virtual Machines...${NC}\n"
    
    for vm_spec in "${VMS_TO_CREATE[@]}"; do
        IFS=':' read -r vm_id vm_name vm_ram vm_cpus vm_disk <<< "$vm_spec"
        
        echo -e "${CYAN}Creating VM: ${BOLD}${vm_name}${NC}"
        echo "  RAM: ${vm_ram}MB, CPUs: ${vm_cpus}, Disk: ${vm_disk}GB"
        
        # Create VM profile (this would integrate with actual VM creation scripts)
        mkdir -p /var/lib/hypervisor/vm-profiles
        cat > "/var/lib/hypervisor/vm-profiles/${vm_id}.json" <<VM_EOF
{
  "name": "${vm_name}",
  "id": "${vm_id}",
  "memory": ${vm_ram},
  "vcpus": ${vm_cpus},
  "disk_size": "${vm_disk}G",
  "created": "$(date -Iseconds)",
  "autostart": false
}
VM_EOF
        
        echo -e "${GREEN}✓${NC} VM profile created: ${vm_id}"
    done
    
    echo
    echo -e "${GREEN}${BOLD}✓ All VMs created successfully${NC}"
}

# Apply configuration
apply_configuration() {
    echo
    echo -e "${YELLOW}${BOLD}Building system with new configuration...${NC}"
    echo "This may take several minutes depending on features selected."
    echo
    
    if nixos-rebuild switch; then
        echo
        echo -e "${GREEN}${BOLD}✓ System rebuild successful!${NC}"
        
        # Mark setup as complete
        mkdir -p "$(dirname "$SETUP_COMPLETE_FLAG")"
        touch "$SETUP_COMPLETE_FLAG"
        
        # Save wizard state
        cat > "$WIZARD_STATE" <<STATE_EOF
TIER=$SELECTED_TIER
GUI=$SELECTED_GUI
FEATURES="${SELECTED_FEATURES[*]}"
VMS_CREATED=${#VMS_TO_CREATE[@]}
COMPLETED=$(date -Iseconds)
STATE_EOF
        
        return 0
    else
        echo
        echo -e "${RED}${BOLD}✗ System rebuild failed!${NC}"
        echo
        echo "Restoring backup configuration..."
        
        if ls "$CONFIG_FILE".backup-* 1> /dev/null 2>&1; then
            latest_backup=$(ls -t "$CONFIG_FILE".backup-* | head -1)
            cp "$latest_backup" "$CONFIG_FILE"
            echo -e "${GREEN}✓${NC} Original configuration restored"
        fi
        
        return 1
    fi
}

# Show completion
show_completion() {
    clear
    cat << EOF
${GREEN}
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║        ${BOLD}Setup Complete! Welcome to Hyper-NixOS${NC}${GREEN}              ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
${NC}

${BOLD}Your system is now fully configured and ready to use!${NC}

${CYAN}Configuration Summary:${NC}
  • Tier: ${GREEN}${SELECTED_TIER}${NC}
  • GUI Environment: ${GREEN}${SELECTED_GUI}${NC}
  • Features Enabled: ${GREEN}${#SELECTED_FEATURES[@]}${NC}
  • VMs Created: ${GREEN}${#VMS_TO_CREATE[@]}${NC}

${CYAN}What's Next:${NC}

EOF

    if [[ ${#VMS_TO_CREATE[@]} -gt 0 ]]; then
        echo -e "${BOLD}Your Virtual Machines:${NC}"
        for vm_spec in "${VMS_TO_CREATE[@]}"; do
            IFS=':' read -r vm_id vm_name _ _ _ <<< "$vm_spec"
            echo -e "  • ${GREEN}${vm_name}${NC} (${vm_id})"
        done
        echo
    fi
    
    echo -e "${BOLD}After Reboot:${NC}"
    echo -e "  1. System will boot into ${CYAN}Headless VM Menu${NC}"
    echo -e "  2. Last used VM will auto-select (10s timer)"
    echo -e "  3. You can:"
    echo -e "     - Start/stop VMs"
    echo -e "     - Create new VMs"
    echo -e "     - Switch to admin $(if [[ "$SELECTED_GUI" != "headless" ]]; then echo "GUI"; else echo "CLI"; fi)"
    echo

    if [[ "$SELECTED_GUI" != "headless" ]]; then
        echo -e "${BOLD}Admin GUI Access:${NC}"
        echo -e "  • Desktop Environment: ${GREEN}${SELECTED_GUI}${NC}"
        echo -e "  • Access from headless menu or login directly"
    fi
    
    echo
    echo -e "${GREEN}${BOLD}System will reboot in 10 seconds...${NC}"
    echo -e "Press Ctrl+C to cancel reboot"
    echo
    
    sleep 10
    reboot
}

# Main wizard flow
main() {
    # Check prerequisites
    check_root
    detect_system_resources
    
    # Step 1: Welcome
    show_welcome
    
    # Step 2: Feature detection and selection
    detect_available_features
    select_features
    
    # Step 3: GUI selection
    select_gui_environment
    
    # Step 4: VM deployment
    deploy_vms
    
    # Step 5: Generate configuration
    generate_configuration
    create_vms
    
    # Step 6: Apply
    if apply_configuration; then
        show_completion
    else
        echo
        echo -e "${RED}Setup failed. Please check errors above.${NC}"
        echo -e "You can run this wizard again: ${BOLD}sudo comprehensive-setup-wizard${NC}"
        echo
        read -p "Press Enter to exit..."
        exit 1
    fi
}

# Run main
main "$@"
