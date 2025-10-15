#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Hyper-NixOS Headless VM Menu
# Boot-time menu for VM management with auto-select
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
readonly VM_PROFILES_DIR="/var/lib/hypervisor/vm_profiles"
readonly LAST_VM_FILE="/var/lib/hypervisor/.last_vm"
readonly AUTO_SELECT_TIMEOUT=10  # seconds
readonly CONFIG_FILE="/etc/nixos/configuration.nix"

# VM list
declare -a VM_LIST
declare -a VM_IDS
declare -a VM_STATES

# Get VM state using virsh
get_vm_state() {
    local vm_id=$1
    if virsh list --all | grep -q " ${vm_id} "; then
        virsh domstate "$vm_id" 2>/dev/null || echo "unknown"
    else
        echo "undefined"
    fi
}

# Load VMs
load_vms() {
    VM_LIST=()
    VM_IDS=()
    VM_STATES=()
    
    if [[ ! -d "$VM_PROFILES_DIR" ]]; then
        return 0
    fi
    
    shopt -s nullglob
    for profile in "$VM_PROFILES_DIR"/*.json; do
        if [[ -f "$profile" ]]; then
            local vm_id=$(basename "$profile" .json)
            local vm_name=$(jq -r '.name // .id' "$profile" 2>/dev/null || echo "$vm_id")
            local vm_state=$(get_vm_state "$vm_id")
            
            VM_IDS+=("$vm_id")
            VM_LIST+=("$vm_name")
            VM_STATES+=("$vm_state")
        fi
    done
    shopt -u nullglob
}

# Show header
show_header() {
    clear
    cat << EOF
${CYAN}
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║              ${BOLD}Hyper-NixOS Virtual Machine Menu${NC}${CYAN}                ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
${NC}
EOF
}

# Show VM list
show_vm_list() {
    if [[ ${#VM_LIST[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No VMs found.${NC}"
        echo
        return 1
    fi
    
    echo -e "${BOLD}Virtual Machines:${NC}"
    echo
    
    local i=1
    for idx in "${!VM_LIST[@]}"; do
        local vm_name="${VM_LIST[$idx]}"
        local vm_state="${VM_STATES[$idx]}"
        
        # Color code state
        local state_color="$NC"
        local state_text="$vm_state"
        case $vm_state in
            running)
                state_color="$GREEN"
                state_text="● RUNNING"
                ;;
            "shut off"|shutoff)
                state_color="$RED"
                state_text="○ STOPPED"
                ;;
            paused)
                state_color="$YELLOW"
                state_text="‖ PAUSED"
                ;;
            *)
                state_color="$NC"
                state_text="? ${vm_state}"
                ;;
        esac
        
        echo -e "  ${GREEN}${i})${NC} ${BOLD}${vm_name}${NC} ${state_color}${state_text}${NC}"
        ((i++))
    done
    
    return 0
}

# Show menu options
show_menu() {
    echo
    echo -e "${BOLD}Options:${NC}"
    echo -e "  ${GREEN}[number]${NC} - Manage VM (start/stop/console)"
    echo -e "  ${GREEN}c${NC} - Create new VM"
    echo -e "  ${GREEN}a${NC} - Switch to admin environment"
    echo -e "  ${GREEN}r${NC} - Refresh VM list"
    echo -e "  ${GREEN}s${NC} - System shutdown"
    echo -e "  ${GREEN}q${NC} - Exit to shell"
    echo
}

# Auto-select last VM
auto_select_vm() {
    if [[ ! -f "$LAST_VM_FILE" ]]; then
        return 1
    fi
    
    local last_vm_id=$(cat "$LAST_VM_FILE")
    
    # Find VM in list
    for idx in "${!VM_IDS[@]}"; do
        if [[ "${VM_IDS[$idx]}" == "$last_vm_id" ]]; then
            echo
            echo -e "${CYAN}Last used VM: ${BOLD}${VM_LIST[$idx]}${NC}"
            echo -e "${YELLOW}Auto-starting in ${AUTO_SELECT_TIMEOUT} seconds...${NC}"
            echo -e "Press any key to cancel"
            
            # Countdown with key detection
            for ((i=AUTO_SELECT_TIMEOUT; i>0; i--)); do
                echo -ne "\r${YELLOW}Starting in ${i}...${NC} "
                
                # Check for key press (non-blocking)
                if read -t 1 -n 1 -s; then
                    echo
                    echo -e "${GREEN}Auto-start cancelled${NC}"
                    sleep 1
                    return 1
                fi
            done
            
            echo
            echo -e "${GREEN}Starting ${VM_LIST[$idx]}...${NC}"
            start_vm "$last_vm_id" "${VM_LIST[$idx]}"
            return 0
        fi
    done
    
    return 1
}

# Start VM
start_vm() {
    local vm_id=$1
    local vm_name=$2
    
    echo -e "${BLUE}Starting VM: ${BOLD}${vm_name}${NC}"
    
    if virsh start "$vm_id" 2>/dev/null; then
        echo -e "${GREEN}✓ VM started successfully${NC}"
        echo "$vm_id" > "$LAST_VM_FILE"
        sleep 2
    else
        echo -e "${RED}✗ Failed to start VM${NC}"
        echo "VM may already be running or there was an error"
        sleep 3
    fi
}

# Stop VM
stop_vm() {
    local vm_id=$1
    local vm_name=$2
    
    echo
    echo -e "${YELLOW}Stopping VM: ${BOLD}${vm_name}${NC}"
    read -p "Graceful shutdown? (y/N): " graceful
    
    if [[ $graceful =~ ^[Yy]$ ]]; then
        echo "Sending shutdown signal..."
        virsh shutdown "$vm_id"
    else
        echo "Forcing power off..."
        virsh destroy "$vm_id"
    fi
    
    echo -e "${GREEN}✓ VM stopped${NC}"
    sleep 2
}

# VM console
vm_console() {
    local vm_id=$1
    local vm_name=$2
    
    echo
    echo -e "${CYAN}Connecting to VM console: ${BOLD}${vm_name}${NC}"
    echo -e "${YELLOW}Press Ctrl+] to exit console${NC}"
    echo
    sleep 2
    
    virsh console "$vm_id"
}

# Manage VM menu
manage_vm() {
    local idx=$1
    local vm_id="${VM_IDS[$idx]}"
    local vm_name="${VM_LIST[$idx]}"
    local vm_state="${VM_STATES[$idx]}"
    
    while true; do
        show_header
        echo -e "${BOLD}Managing: ${CYAN}${vm_name}${NC}"
        echo -e "State: ${vm_state}"
        echo
        echo -e "${BOLD}Actions:${NC}"
        
        case $vm_state in
            running)
                echo -e "  ${GREEN}1)${NC} Open console"
                echo -e "  ${GREEN}2)${NC} Stop VM"
                echo -e "  ${GREEN}3)${NC} Pause VM"
                ;;
            "shut off"|shutoff)
                echo -e "  ${GREEN}1)${NC} Start VM"
                ;;
            paused)
                echo -e "  ${GREEN}1)${NC} Resume VM"
                echo -e "  ${GREEN}2)${NC} Stop VM"
                ;;
        esac
        
        echo -e "  ${GREEN}v)${NC} View VM details"
        echo -e "  ${GREEN}b)${NC} Back to main menu"
        echo
        read -p "Enter choice: " action
        
        case $action in
            1)
                if [[ "$vm_state" == "running" ]]; then
                    vm_console "$vm_id" "$vm_name"
                    vm_state=$(get_vm_state "$vm_id")
                elif [[ "$vm_state" == "shut off" || "$vm_state" == "shutoff" ]]; then
                    start_vm "$vm_id" "$vm_name"
                    vm_state=$(get_vm_state "$vm_id")
                elif [[ "$vm_state" == "paused" ]]; then
                    virsh resume "$vm_id"
                    vm_state=$(get_vm_state "$vm_id")
                fi
                ;;
            2)
                if [[ "$vm_state" == "running" ]]; then
                    stop_vm "$vm_id" "$vm_name"
                    vm_state=$(get_vm_state "$vm_id")
                elif [[ "$vm_state" == "paused" ]]; then
                    stop_vm "$vm_id" "$vm_name"
                    vm_state=$(get_vm_state "$vm_id")
                fi
                ;;
            3)
                if [[ "$vm_state" == "running" ]]; then
                    virsh suspend "$vm_id"
                    vm_state=$(get_vm_state "$vm_id")
                fi
                ;;
            v|V)
                show_header
                echo -e "${BOLD}VM Details: ${vm_name}${NC}\n"
                virsh dominfo "$vm_id"
                echo
                read -p "Press Enter to continue..."
                ;;
            b|B)
                break
                ;;
        esac
    done
}

# Create new VM
create_new_vm() {
    show_header
    echo -e "${CYAN}${BOLD}Create New Virtual Machine${NC}\n"
    
    echo "This will launch the VM creation wizard."
    echo
    read -p "Continue? (y/N): " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        # This would call the actual VM creation wizard
        # For now, just show a placeholder
        echo
        echo -e "${YELLOW}Launching VM creation wizard...${NC}"
        sleep 1
        
        # Check if virt-manager is available
        if command -v virt-manager >/dev/null 2>&1; then
            virt-manager &
        else
            echo -e "${RED}virt-manager not available${NC}"
            echo "Install with: nix-env -iA nixos.virt-manager"
        fi
        
        sleep 2
    fi
}

# Switch to admin environment
switch_to_admin() {
    show_header
    echo -e "${CYAN}${BOLD}Switch to Admin Environment${NC}\n"
    
    # Detect GUI environment from config
    local has_gui=false
    local gui_env="none"
    
    if grep -q 'hypervisor.gui.enable = true' "$CONFIG_FILE" 2>/dev/null; then
        has_gui=true
        gui_env=$(grep 'environment =' "$CONFIG_FILE" | cut -d'"' -f2 || echo "unknown")
    fi
    
    echo -e "${BOLD}Available options:${NC}"
    echo
    
    if [[ "$has_gui" == "true" && "$gui_env" != "headless" ]]; then
        echo -e "  ${GREEN}1)${NC} Start ${BOLD}${gui_env}${NC} desktop session"
        echo -e "  ${GREEN}2)${NC} Admin shell (CLI)"
        echo -e "  ${GREEN}3)${NC} SSH access info"
    else
        echo -e "  ${GREEN}1)${NC} Admin shell (CLI)"
        echo -e "  ${GREEN}2)${NC} SSH access info"
    fi
    
    echo -e "  ${GREEN}b)${NC} Back"
    echo
    read -p "Enter choice: " admin_choice
    
    case $admin_choice in
        1)
            if [[ "$has_gui" == "true" && "$gui_env" != "headless" ]]; then
                echo
                echo -e "${GREEN}Starting ${gui_env} desktop...${NC}"
                sleep 1
                systemctl start display-manager
                exit 0
            else
                echo
                echo -e "${GREEN}Switching to admin shell...${NC}"
                sleep 1
                exec bash -l
            fi
            ;;
        2)
            if [[ "$has_gui" == "true" && "$gui_env" != "headless" ]]; then
                echo
                echo -e "${GREEN}Switching to admin shell...${NC}"
                sleep 1
                exec bash -l
            else
                show_ssh_info
            fi
            ;;
        3)
            show_ssh_info
            ;;
    esac
}

# Show SSH info
show_ssh_info() {
    show_header
    echo -e "${CYAN}${BOLD}SSH Access Information${NC}\n"
    
    local ip_addr=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1 | head -1)
    
    echo -e "${BOLD}SSH Connection:${NC}"
    echo -e "  ssh <username>@${GREEN}${ip_addr}${NC}"
    echo
    echo -e "${BOLD}Available users:${NC}"
    getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print "  " $1}' | grep -v nobody
    echo
    read -p "Press Enter to continue..."
}

# Main menu loop
main_menu() {
    while true; do
        load_vms
        show_header
        
        if show_vm_list; then
            show_menu
            read -p "Enter choice: " choice
            
            case $choice in
                [0-9]*)
                    local idx=$((choice - 1))
                    if [[ $idx -ge 0 && $idx -lt ${#VM_LIST[@]} ]]; then
                        manage_vm "$idx"
                    else
                        echo -e "${RED}Invalid VM number${NC}"
                        sleep 1
                    fi
                    ;;
                c|C)
                    create_new_vm
                    ;;
                a|A)
                    switch_to_admin
                    ;;
                r|R)
                    echo -e "${GREEN}Refreshing...${NC}"
                    sleep 1
                    ;;
                s|S)
                    echo
                    read -p "Shutdown system? (yes/NO): " confirm
                    if [[ "$confirm" == "yes" ]]; then
                        echo -e "${YELLOW}Shutting down...${NC}"
                        systemctl poweroff
                    fi
                    ;;
                q|Q)
                    echo
                    echo -e "${GREEN}Exiting to shell...${NC}"
                    sleep 1
                    exit 0
                    ;;
                *)
                    echo -e "${RED}Invalid choice${NC}"
                    sleep 1
                    ;;
            esac
        else
            # No VMs found
            show_menu
            read -p "Enter choice: " choice
            
            case $choice in
                c|C) create_new_vm ;;
                a|A) switch_to_admin ;;
                q|Q) exit 0 ;;
                *) sleep 1 ;;
            esac
        fi
    done
}

# Main entry point
main() {
    # Check if setup is complete
    if [[ ! -f "/var/lib/hypervisor/.setup-complete" ]]; then
        echo -e "${YELLOW}Setup not complete. Please run: sudo comprehensive-setup-wizard${NC}"
        sleep 3
        exit 1
    fi
    
    # Load VMs
    load_vms
    
    # Show header
    show_header
    
    # Try auto-select if VMs exist
    if [[ ${#VM_LIST[@]} -gt 0 ]]; then
        if ! auto_select_vm; then
            # Auto-select cancelled or failed, show menu
            main_menu
        else
            # VM started, enter main menu
            sleep 2
            main_menu
        fi
    else
        # No VMs, go straight to menu
        main_menu
    fi
}

# Run
main "$@"
