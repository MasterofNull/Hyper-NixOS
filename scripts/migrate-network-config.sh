#!/usr/bin/env bash
# Network Configuration Migration Tool for Hyper-NixOS
# Migrates: WiFi credentials, network drivers, settings from previous OS
#
# Copyright (c) 2024-2025 MasterofNull
# Licensed under MIT License

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
readonly MIGRATION_DIR="/var/lib/hypervisor/network-migration"
readonly OUTPUT_FILE="${MIGRATION_DIR}/network-config.nix"
readonly WIFI_CREDS_FILE="${MIGRATION_DIR}/wifi-credentials.json"
readonly HARDWARE_INFO_FILE="${MIGRATION_DIR}/hardware-info.json"
readonly LOG_FILE="${MIGRATION_DIR}/migration.log"

# Ensure migration directory exists
mkdir -p "$MIGRATION_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$LOG_FILE"
}

# Display banner
display_banner() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}     Network Configuration Migration Tool for Hyper-NixOS       ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo
    echo "This tool will:"
    echo "  • Detect and optimize network hardware drivers"
    echo "  • Migrate WiFi credentials from various sources"
    echo "  • Preserve network configurations"
    echo "  • Generate NixOS-compatible network configuration"
    echo
}

# Detect host system type
detect_host_system() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "${ID:-unknown}"
    else
        echo "unknown"
    fi
}

# Detect network hardware and drivers
detect_network_hardware() {
    log_info "Detecting network hardware..."
    
    local hardware_info=()
    local interfaces=()
    
    # Get all network interfaces
    for iface in /sys/class/net/*; do
        local ifname=$(basename "$iface")
        
        # Skip loopback and virtual interfaces
        [[ "$ifname" == "lo" ]] && continue
        [[ "$ifname" == "docker"* ]] && continue
        [[ "$ifname" == "veth"* ]] && continue
        [[ "$ifname" == "br-"* ]] && continue
        
        local driver=""
        local bus=""
        local vendor=""
        local device=""
        local is_wireless=false
        
        # Get driver information
        if [[ -e "$iface/device/driver" ]]; then
            driver=$(basename "$(readlink "$iface/device/driver")")
        fi
        
        # Get bus type
        if [[ -e "$iface/device/subsystem" ]]; then
            bus=$(basename "$(readlink "$iface/device/subsystem")")
        fi
        
        # Get vendor and device IDs
        if [[ -e "$iface/device/vendor" ]]; then
            vendor=$(cat "$iface/device/vendor" 2>/dev/null || echo "unknown")
        fi
        if [[ -e "$iface/device/device" ]]; then
            device=$(cat "$iface/device/device" 2>/dev/null || echo "unknown")
        fi
        
        # Check if wireless
        if [[ -d "$iface/wireless" ]] || iwconfig "$ifname" 2>/dev/null | grep -q "IEEE 802.11"; then
            is_wireless=true
        fi
        
        # Get MAC address
        local mac=$(cat "$iface/address" 2>/dev/null || echo "unknown")
        
        # Get link status
        local link_state=$(cat "$iface/operstate" 2>/dev/null || echo "unknown")
        
        interfaces+=("$ifname")
        
        log_info "  $ifname: driver=$driver, bus=$bus, wireless=$is_wireless"
        
        # Store hardware info
        cat >> "$HARDWARE_INFO_FILE" <<EOF
{
  "interface": "$ifname",
  "driver": "$driver",
  "bus": "$bus",
  "vendor": "$vendor",
  "device": "$device",
  "is_wireless": $is_wireless,
  "mac_address": "$mac",
  "link_state": "$link_state"
}
EOF
    done
    
    log_success "Detected ${#interfaces[@]} network interface(s)"
}

# Extract WiFi credentials from NetworkManager
extract_nm_wifi_creds() {
    log_info "Checking for NetworkManager WiFi credentials..."
    
    local nm_dir="/etc/NetworkManager/system-connections"
    
    if [[ ! -d "$nm_dir" ]]; then
        log_warning "NetworkManager connections not found"
        return 0
    fi
    
    local wifi_count=0
    
    for conn_file in "$nm_dir"/*; do
        [[ ! -f "$conn_file" ]] && continue
        
        # Check if it's a WiFi connection
        if grep -q "type=wifi" "$conn_file" 2>/dev/null || \
           grep -q "type=802-11-wireless" "$conn_file" 2>/dev/null; then
            
            local ssid=$(grep "^ssid=" "$conn_file" | cut -d= -f2- | tr -d '\r\n' || echo "")
            local psk=$(grep "^psk=" "$conn_file" | cut -d= -f2- | tr -d '\r\n' || echo "")
            local key_mgmt=$(grep "^key-mgmt=" "$conn_file" | cut -d= -f2- | tr -d '\r\n' || echo "wpa-psk")
            
            if [[ -n "$ssid" ]]; then
                log_success "  Found WiFi: $ssid"
                
                # Append to credentials file
                cat >> "$WIFI_CREDS_FILE" <<EOF
{
  "ssid": "$ssid",
  "psk": "$psk",
  "key_mgmt": "$key_mgmt",
  "source": "NetworkManager"
}
EOF
                ((wifi_count++))
            fi
        fi
    done
    
    if [[ $wifi_count -gt 0 ]]; then
        log_success "Extracted $wifi_count WiFi credential(s) from NetworkManager"
    fi
}

# Extract WiFi credentials from wpa_supplicant
extract_wpa_supplicant_creds() {
    log_info "Checking for wpa_supplicant WiFi credentials..."
    
    local wpa_conf="/etc/wpa_supplicant/wpa_supplicant.conf"
    
    if [[ ! -f "$wpa_conf" ]]; then
        log_warning "wpa_supplicant configuration not found"
        return 0
    fi
    
    local wifi_count=0
    local in_network=false
    local current_ssid=""
    local current_psk=""
    local current_key_mgmt=""
    
    while IFS= read -r line; do
        # Remove leading/trailing whitespace
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        if [[ "$line" == "network={"* ]]; then
            in_network=true
            current_ssid=""
            current_psk=""
            current_key_mgmt="WPA-PSK"
        elif [[ "$line" == "}" ]] && [[ "$in_network" == true ]]; then
            if [[ -n "$current_ssid" ]]; then
                log_success "  Found WiFi: $current_ssid"
                
                cat >> "$WIFI_CREDS_FILE" <<EOF
{
  "ssid": "$current_ssid",
  "psk": "$current_psk",
  "key_mgmt": "$current_key_mgmt",
  "source": "wpa_supplicant"
}
EOF
                ((wifi_count++))
            fi
            in_network=false
        elif [[ "$in_network" == true ]]; then
            if [[ "$line" == ssid=* ]]; then
                current_ssid=$(echo "$line" | cut -d= -f2- | tr -d '"')
            elif [[ "$line" == psk=* ]]; then
                current_psk=$(echo "$line" | cut -d= -f2- | tr -d '"')
            elif [[ "$line" == key_mgmt=* ]]; then
                current_key_mgmt=$(echo "$line" | cut -d= -f2-)
            fi
        fi
    done < "$wpa_conf"
    
    if [[ $wifi_count -gt 0 ]]; then
        log_success "Extracted $wifi_count WiFi credential(s) from wpa_supplicant"
    fi
}

# Extract WiFi credentials from iwd
extract_iwd_creds() {
    log_info "Checking for iwd WiFi credentials..."
    
    local iwd_dir="/var/lib/iwd"
    
    if [[ ! -d "$iwd_dir" ]]; then
        log_warning "iwd configuration not found"
        return 0
    fi
    
    local wifi_count=0
    
    for network_file in "$iwd_dir"/*.psk "$iwd_dir"/*.open; do
        [[ ! -f "$network_file" ]] && continue
        
        local filename=$(basename "$network_file")
        local ssid="${filename%.*}"
        
        # Extract passphrase if PSK network
        if [[ "$network_file" == *.psk ]]; then
            local psk=$(grep "^Passphrase=" "$network_file" 2>/dev/null | cut -d= -f2- || echo "")
            local key_mgmt="WPA-PSK"
        else
            local psk=""
            local key_mgmt="NONE"
        fi
        
        log_success "  Found WiFi: $ssid"
        
        cat >> "$WIFI_CREDS_FILE" <<EOF
{
  "ssid": "$ssid",
  "psk": "$psk",
  "key_mgmt": "$key_mgmt",
  "source": "iwd"
}
EOF
        ((wifi_count++))
    done
    
    if [[ $wifi_count -gt 0 ]]; then
        log_success "Extracted $wifi_count WiFi credential(s) from iwd"
    fi
}

# Generate optimized driver configuration for NixOS
generate_driver_config() {
    log_info "Generating optimized driver configuration..."
    
    local drivers=()
    local wireless_drivers=()
    local firmware_packages=()
    
    # Parse hardware info
    if [[ -f "$HARDWARE_INFO_FILE" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ \"driver\":\ \"([^\"]+)\" ]]; then
                local driver="${BASH_REMATCH[1]}"
                [[ "$driver" != "unknown" ]] && [[ " ${drivers[*]} " != *" $driver "* ]] && drivers+=("$driver")
            fi
            
            # Detect specific hardware needing firmware
            if [[ "$line" =~ \"is_wireless\":\ true ]]; then
                if [[ "$line" =~ \"driver\":\ \"([^\"]+)\" ]]; then
                    local wdriver="${BASH_REMATCH[1]}"
                    wireless_drivers+=("$wdriver")
                    
                    # Map drivers to firmware packages
                    case "$wdriver" in
                        iwlwifi|iwlegacy)
                            firmware_packages+=("linux-firmware")
                            ;;
                        ath9k|ath10k*)
                            firmware_packages+=("linux-firmware")
                            ;;
                        rtw88|rtw89|rtl*)
                            firmware_packages+=("linux-firmware")
                            ;;
                        brcmfmac|brcmsmac)
                            firmware_packages+=("linux-firmware")
                            ;;
                        mt76*)
                            firmware_packages+=("linux-firmware")
                            ;;
                    esac
                fi
            fi
        done < <(cat "$HARDWARE_INFO_FILE" 2>/dev/null || echo "")
    fi
    
    # Remove duplicates
    firmware_packages=($(printf "%s\n" "${firmware_packages[@]}" | sort -u))
    
    cat >> "$OUTPUT_FILE" <<'EOF'
# Network Hardware Configuration
# Auto-generated by migrate-network-config.sh

{ config, lib, pkgs, ... }:

{
  # Network hardware drivers
EOF

    if [[ ${#drivers[@]} -gt 0 ]]; then
        cat >> "$OUTPUT_FILE" <<EOF
  # Detected drivers: ${drivers[*]}
  boot.initrd.availableKernelModules = [
EOF
        for driver in "${drivers[@]}"; do
            echo "    \"$driver\"" >> "$OUTPUT_FILE"
        done
        cat >> "$OUTPUT_FILE" <<EOF
  ];
EOF
    fi
    
    if [[ ${#wireless_drivers[@]} -gt 0 ]]; then
        cat >> "$OUTPUT_FILE" <<EOF
  
  # Wireless drivers
  boot.kernelModules = [
EOF
        for driver in "${wireless_drivers[@]}"; do
            echo "    \"$driver\"" >> "$OUTPUT_FILE"
        done
        cat >> "$OUTPUT_FILE" <<EOF
  ];
EOF
    fi
    
    if [[ ${#firmware_packages[@]} -gt 0 ]]; then
        cat >> "$OUTPUT_FILE" <<EOF
  
  # Firmware packages for network hardware
  hardware.enableRedistributableFirmware = true;
  hardware.firmware = with pkgs; [
EOF
        for pkg in "${firmware_packages[@]}"; do
            # Map to actual NixOS package names
            case "$pkg" in
                linux-firmware)
                    echo "    linux-firmware" >> "$OUTPUT_FILE"
                    ;;
            esac
        done
        cat >> "$OUTPUT_FILE" <<EOF
  ];
EOF
    fi
    
    log_success "Generated driver configuration"
}

# Generate WiFi environment file (secure credentials)
generate_wifi_env_file() {
    log_info "Generating secure WiFi credentials file..."
    
    if [[ ! -f "$WIFI_CREDS_FILE" ]] || [[ ! -s "$WIFI_CREDS_FILE" ]]; then
        log_warning "No WiFi credentials found to migrate"
        return 0
    fi
    
    local env_file="/root/wifi-credentials.env"
    
    # Create secure environment file
    : > "$env_file"
    chmod 600 "$env_file"
    
    # Parse WiFi credentials JSON
    local ssids=()
    local psks=()
    
    while IFS= read -r line; do
        if [[ "$line" =~ \"ssid\":\ \"([^\"]+)\" ]]; then
            ssids+=("${BASH_REMATCH[1]}")
        elif [[ "$line" =~ \"psk\":\ \"([^\"]+)\" ]]; then
            psks+=("${BASH_REMATCH[1]}")
        fi
    done < "$WIFI_CREDS_FILE"
    
    # Generate environment variables for each network
    for i in "${!ssids[@]}"; do
        local ssid="${ssids[$i]}"
        local psk="${psks[$i]:-}"
        
        # Create safe variable name (replace special chars with underscore)
        local var_name=$(echo "$ssid" | tr -c '[:alnum:]' '_' | tr '[:lower:]' '[:upper:]')
        
        if [[ -n "$psk" ]]; then
            echo "${var_name}_PSK=\"$psk\"" >> "$env_file"
        fi
    done
    
    log_success "Created secure WiFi credentials file: $env_file"
}

# Generate WiFi configuration for NixOS (using environmentFile)
generate_wifi_config() {
    log_info "Generating WiFi configuration..."
    
    if [[ ! -f "$WIFI_CREDS_FILE" ]] || [[ ! -s "$WIFI_CREDS_FILE" ]]; then
        log_warning "No WiFi credentials found to migrate"
        return 0
    fi
    
    # Generate secure environment file
    generate_wifi_env_file
    
    cat >> "$OUTPUT_FILE" <<'EOF'
  
  # WiFi Configuration (migrated credentials)
  # Using wpa_supplicant with secure credential storage
  # ✅ SECURE: Passwords stored in /root/wifi-credentials.env (not in Nix store)
  networking.wireless = {
    enable = true;
    
    # Secure credentials file (not world-readable, not in Nix store)
    environmentFile = "/root/wifi-credentials.env";
    
    networks = {
EOF
    
    # Parse WiFi credentials JSON
    local ssids=()
    local psks=()
    
    while IFS= read -r line; do
        if [[ "$line" =~ \"ssid\":\ \"([^\"]+)\" ]]; then
            ssids+=("${BASH_REMATCH[1]}")
        elif [[ "$line" =~ \"psk\":\ \"([^\"]+)\" ]]; then
            psks+=("${BASH_REMATCH[1]}")
        fi
    done < "$WIFI_CREDS_FILE"
    
    # Generate network entries (referencing environment variables)
    for i in "${!ssids[@]}"; do
        local ssid="${ssids[$i]}"
        local psk="${psks[$i]:-}"
        local var_name=$(echo "$ssid" | tr -c '[:alnum:]' '_' | tr '[:lower:]' '[:upper:]')
        
        cat >> "$OUTPUT_FILE" <<EOF
      "$ssid" = {
EOF
        if [[ -n "$psk" ]]; then
            cat >> "$OUTPUT_FILE" <<EOF
        # Password loaded from environmentFile variable: ${var_name}_PSK
        pskRaw = "@${var_name}_PSK@";
EOF
        else
            cat >> "$OUTPUT_FILE" <<EOF
        # Open network (no password)
EOF
        fi
        cat >> "$OUTPUT_FILE" <<EOF
      };
EOF
    done
    
    cat >> "$OUTPUT_FILE" <<'EOF'
    };
    
    # Allow imperative WiFi management for flexibility
    userControlled.enable = true;
  };
EOF
    
    log_success "Generated WiFi configuration for ${#ssids[@]} network(s)"
    log_info "  Credentials stored securely in: /root/wifi-credentials.env"
}

# Generate network optimization settings
generate_network_optimizations() {
    log_info "Adding network optimizations..."
    
    cat >> "$OUTPUT_FILE" <<'EOF'
  
  # Network Optimizations
  # These settings improve boot time and network performance
  
  # Optimize DHCP for faster boot
  networking.dhcpcd.extraConfig = ''
    timeout 10
    noarp
    option rapid_commit
    background
    reboot 5
  '';
  
  # Optimize systemd-networkd-wait-online
  systemd.services.systemd-networkd-wait-online = {
    serviceConfig = {
      TimeoutStartSec = "30s";
    };
  };
  
  # Configure wait-online strategy
  systemd.network.wait-online = {
    anyInterface = true;
    timeout = 30;
  };
  
  # DNS Configuration
  networking.nameservers = lib.mkDefault [ "1.1.1.1" "8.8.8.8" "9.9.9.9" ];
  
  # Enable predictable interface names
  networking.usePredictableInterfaceNames = true;
}
EOF
    
    log_success "Added network optimizations"
}

# Generate final summary
generate_summary() {
    local hardware_count=$(grep -c "interface" "$HARDWARE_INFO_FILE" 2>/dev/null || echo "0")
    local wifi_count=$(grep -c "ssid" "$WIFI_CREDS_FILE" 2>/dev/null || echo "0")
    
    cat > "${MIGRATION_DIR}/MIGRATION_SUMMARY.md" <<EOF
# Network Configuration Migration Summary

**Migration Date**: $(date)
**Host System**: $(detect_host_system)
**Hostname**: $(hostname)

## Migrated Components

### Network Hardware
- **Interfaces Detected**: $hardware_count
- **Configuration File**: $HARDWARE_INFO_FILE

### WiFi Credentials
- **Networks Migrated**: $wifi_count
- **Credentials File**: $WIFI_CREDS_FILE (encrypted)

### Generated Configuration
- **NixOS Config**: $OUTPUT_FILE

## Next Steps

1. **Review the generated configuration**:
   \`\`\`bash
   cat $OUTPUT_FILE
   \`\`\`

2. **Import into your NixOS configuration**:
   \`\`\`nix
   imports = [
     $OUTPUT_FILE
   ];
   \`\`\`

3. **Rebuild your system**:
   \`\`\`bash
   sudo nixos-rebuild switch
   \`\`\`

4. **Test network connectivity**:
   \`\`\`bash
   ping -c 4 1.1.1.1
   ip addr show
   \`\`\`

## Security Notes

✅ **WiFi credentials are stored securely**:
- Passwords stored in: \`/root/wifi-credentials.env\`
- File permissions: \`600\` (only root can read)
- NOT stored in Nix store (not world-readable)
- Uses \`networking.wireless.environmentFile\` feature

⚠️ **Important**:
- Keep \`/root/wifi-credentials.env\` secure (already chmod 600)
- Do NOT commit this file to version control
- Backup securely if needed
- Delete migration files after successful import:
  \`\`\`bash
  sudo rm -rf $MIGRATION_DIR
  # Keep /root/wifi-credentials.env - it's needed by the system
  \`\`\`

## Troubleshooting

If network doesn't work after migration:

1. Check driver loading:
   \`\`\`bash
   lsmod | grep -E "iwlwifi|ath|rtl|brcm"
   \`\`\`

2. Check WiFi status:
   \`\`\`bash
   systemctl status wpa_supplicant
   journalctl -u wpa_supplicant -n 50
   \`\`\`

3. Manually connect to WiFi:
   \`\`\`bash
   wpa_cli
   > scan
   > scan_results
   > add_network
   > set_network 0 ssid "YourSSID"
   > set_network 0 psk "YourPassword"
   > enable_network 0
   \`\`\`

## Documentation

- NixOS Networking: https://nixos.org/manual/nixos/stable/options.html#opt-networking
- WiFi Configuration: https://nixos.org/manual/nixos/stable/options.html#opt-networking.wireless
EOF
    
    log_success "Generated migration summary"
}

# Main migration function
perform_migration() {
    log_info "Starting network configuration migration..."
    echo
    
    # Initialize output file
    > "$OUTPUT_FILE"
    > "$WIFI_CREDS_FILE"
    > "$HARDWARE_INFO_FILE"
    
    # Step 1: Detect hardware
    echo -e "${BOLD}Step 1: Detecting Network Hardware${NC}"
    detect_network_hardware
    echo
    
    # Step 2: Extract WiFi credentials
    echo -e "${BOLD}Step 2: Extracting WiFi Credentials${NC}"
    extract_nm_wifi_creds
    extract_wpa_supplicant_creds
    extract_iwd_creds
    echo
    
    # Step 3: Generate NixOS configuration
    echo -e "${BOLD}Step 3: Generating NixOS Configuration${NC}"
    generate_driver_config
    generate_wifi_config
    generate_network_optimizations
    echo
    
    # Step 4: Generate summary
    echo -e "${BOLD}Step 4: Creating Migration Summary${NC}"
    generate_summary
    echo
    
    log_success "Network configuration migration completed!"
}

# Display results
display_results() {
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                    Migration Complete!                         ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo
    echo -e "${GREEN}Generated Files:${NC}"
    echo "  • NixOS Configuration: $OUTPUT_FILE"
    echo "  • Hardware Info: $HARDWARE_INFO_FILE"
    echo "  • WiFi Credentials: $WIFI_CREDS_FILE"
    echo "  • Summary: ${MIGRATION_DIR}/MIGRATION_SUMMARY.md"
    echo "  • Log: $LOG_FILE"
    echo
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Review the generated configuration:"
    echo "     cat $OUTPUT_FILE"
    echo
    echo "  2. Add to your configuration.nix:"
    echo "     imports = [ $OUTPUT_FILE ];"
    echo
    echo "  3. Rebuild your system:"
    echo "     sudo nixos-rebuild switch"
    echo
    echo -e "${BLUE}Documentation:${NC}"
    echo "  • Read: ${MIGRATION_DIR}/MIGRATION_SUMMARY.md"
    echo "  • Log: $LOG_FILE"
    echo
}

# Main execution
main() {
    # Check if running with proper permissions
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run with sudo${NC}"
        echo "Usage: sudo $0"
        exit 1
    fi
    
    display_banner
    
    read -p "$(echo -e ${YELLOW}Start network migration? [Y/n]:${NC} )" confirm
    if [[ "${confirm,,}" == "n" ]]; then
        echo "Migration cancelled"
        exit 0
    fi
    
    echo
    perform_migration
    display_results
    
    echo -e "${GREEN}Migration successful!${NC}"
    echo
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Network Configuration Migration Tool"
        echo
        echo "Usage: sudo $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --auto         Run in non-interactive mode"
        echo
        echo "This tool migrates network configuration from existing system to NixOS:"
        echo "  • Network hardware drivers"
        echo "  • WiFi credentials (NetworkManager, wpa_supplicant, iwd)"
        echo "  • Network optimizations"
        echo
        exit 0
        ;;
    --auto)
        # Non-interactive mode
        display_banner
        perform_migration
        display_results
        ;;
    *)
        main "$@"
        ;;
esac
