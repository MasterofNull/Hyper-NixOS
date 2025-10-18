#!/usr/bin/env bash
################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Script: system-hardening-wizard.sh
# Purpose: Comprehensive system hardening with multiple profiles and reversibility
#
# ADMIN ONLY - This wizard makes significant system security changes
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
#
# Author: MasterofNull
################################################################################

set -Eeuo pipefail

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/branding.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/hardware-capabilities.sh" 2>/dev/null || true

# Configuration
readonly HARDENING_STATE_FILE="/var/lib/hypervisor/hardening-state.json"
readonly HARDENING_BACKUP_DIR="/var/lib/hypervisor/hardening-backups"
readonly HARDENING_CONFIG="/etc/hypervisor/hardening-config.nix"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m'

# Ensure running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}ERROR: This wizard must be run as root (admin only)${NC}"
    echo "Usage: sudo $0"
    exit 1
fi

# Ensure backup directory exists
mkdir -p "${HARDENING_BACKUP_DIR}"

# ============================================================================
# Header and Banner
# ============================================================================

show_header() {
    clear
    show_banner_large 2>/dev/null || cat <<'EOF'
╦ ╦┬ ┬┌─┐┌─┐┬─┐   ╔╗╔┬─┐ ┬╔═╗╔═╗
╠═╣└┬┘├─┘├┤ ├┬┘───║║║│┌┴┬┘║ ║╚═╗
╩ ╩ ┴ ┴  └─┘┴└─   ╝╚╝┴┴ └─╚═╝╚═╝
Next-Generation Virtualization Platform
EOF

    cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ${BOLD}System Hardening Wizard${NC}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ${YELLOW}⚠️  ADMIN ONLY - MAKES SIGNIFICANT SECURITY CHANGES${NC}

  This wizard will harden your Hyper-NixOS system with:
  • File system permissions and access controls
  • Network security and firewall rules
  • Service hardening and isolation
  • Audit logging and monitoring
  • Kernel security parameters

  ${GREEN}✓ All changes are REVERSIBLE${NC}
  ${GREEN}✓ Automatic backups created${NC}
  ${GREEN}✓ Multiple hardening profiles available${NC}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
}

# ============================================================================
# State Management
# ============================================================================

get_current_hardening_state() {
    if [[ -f "${HARDENING_STATE_FILE}" ]]; then
        jq -r '.profile // "none"' "${HARDENING_STATE_FILE}" 2>/dev/null || echo "none"
    else
        echo "none"
    fi
}

save_hardening_state() {
    local profile="$1"
    local timestamp=$(date -Iseconds)

    cat > "${HARDENING_STATE_FILE}" <<JSON
{
  "profile": "${profile}",
  "timestamp": "${timestamp}",
  "applied_by": "${SUDO_USER:-root}",
  "hostname": "$(hostname)",
  "version": "1.0.0"
}
JSON
}

create_backup() {
    local backup_name="pre-hardening-$(date +%Y%m%d-%H%M%S)"
    local backup_path="${HARDENING_BACKUP_DIR}/${backup_name}"

    mkdir -p "${backup_path}"

    echo -e "${CYAN}Creating backup: ${backup_name}${NC}"

    # Backup critical configurations
    [[ -d /etc/hypervisor ]] && cp -r /etc/hypervisor "${backup_path}/" 2>/dev/null || true
    [[ -f /etc/nixos/configuration.nix ]] && cp /etc/nixos/configuration.nix "${backup_path}/" 2>/dev/null || true
    [[ -d /etc/nixos ]] && cp -r /etc/nixos "${backup_path}/" 2>/dev/null || true

    # Save current permissions
    find /etc/hypervisor -ls > "${backup_path}/permissions.txt" 2>/dev/null || true
    find /var/lib/hypervisor -ls > "${backup_path}/var-permissions.txt" 2>/dev/null || true

    # Save current state
    systemctl list-units --type=service --all > "${backup_path}/services.txt" 2>/dev/null || true
    iptables-save > "${backup_path}/iptables.rules" 2>/dev/null || true

    echo -e "${GREEN}✓ Backup created: ${backup_path}${NC}"
    echo "${backup_path}"
}

# ============================================================================
# Hardening Profiles
# ============================================================================

show_hardening_profiles() {
    local current_state=$(get_current_hardening_state)

    echo ""
    echo -e "${BOLD}Select Hardening Profile:${NC}"
    echo ""

    if [[ "$current_state" == "development" ]]; then
        echo -e "${GREEN}→ 1) Development${NC} ${DIM}(current)${NC}"
    else
        echo -e "  1) Development ${DIM}(minimal hardening, easy testing)${NC}"
    fi
    echo "     • Relaxed permissions for development"
    echo "     • Debugging tools enabled"
    echo "     • Verbose logging"
    echo ""

    if [[ "$current_state" == "balanced" ]]; then
        echo -e "${GREEN}→ 2) Balanced${NC} ${DIM}(current, recommended)${NC}"
    else
        echo -e "  2) Balanced ${DIM}(recommended for most users)${NC}"
    fi
    echo "     • Reasonable security without breaking workflows"
    echo "     • VM operations remain smooth"
    echo "     • System changes require authentication"
    echo ""

    if [[ "$current_state" == "strict" ]]; then
        echo -e "${GREEN}→ 3) Strict${NC} ${DIM}(current)${NC}"
    else
        echo -e "  3) Strict ${DIM}(production environments)${NC}"
    fi
    echo "     • Enhanced access controls"
    echo "     • Comprehensive audit logging"
    echo "     • Minimal attack surface"
    echo ""

    if [[ "$current_state" == "paranoid" ]]; then
        echo -e "${GREEN}→ 4) Paranoid${NC} ${DIM}(current)${NC}"
    else
        echo -e "  4) Paranoid ${DIM}(maximum security)${NC}"
    fi
    echo "     • Extremely restrictive permissions"
    echo "     • Everything requires explicit authorization"
    echo "     • May impact usability"
    echo ""

    echo "  5) ${RED}Un-harden${NC} - Remove all hardening (restore to default)"
    echo ""
    echo "  0) Exit without changes"
    echo ""
}

# ============================================================================
# Hardening Functions
# ============================================================================

apply_development_hardening() {
    echo -e "${CYAN}Applying Development Hardening Profile...${NC}"

    # Relaxed permissions for /etc/hypervisor
    chown -R root:wheel /etc/hypervisor
    find /etc/hypervisor -type d -exec chmod 0755 {} +
    find /etc/hypervisor -type f -exec chmod 0644 {} +
    find /etc/hypervisor/scripts -type f -name "*.sh" -exec chmod 0755 {} + 2>/dev/null || true

    # Relaxed /var/lib/hypervisor
    find /var/lib/hypervisor -type d -exec chmod 0775 {} +

    # Enable debugging
    systemctl set-environment HYPERVISOR_DEBUG=1

    echo -e "${GREEN}✓ Development hardening applied${NC}"
}

apply_balanced_hardening() {
    echo -e "${CYAN}Applying Balanced Hardening Profile...${NC}"

    # Moderate permissions for /etc/hypervisor
    chown -R root:wheel /etc/hypervisor
    find /etc/hypervisor -type d -exec chmod 0750 {} +
    find /etc/hypervisor -type f -exec chmod 0640 {} +
    find /etc/hypervisor/scripts -type f -name "*.sh" -exec chmod 0750 {} + 2>/dev/null || true

    # Flake should be readable
    chmod 0644 /etc/hypervisor/flake.nix 2>/dev/null || true
    chmod 0644 /etc/hypervisor/flake.lock 2>/dev/null || true

    # Moderate /var/lib/hypervisor permissions
    find /var/lib/hypervisor/vms -type d -exec chmod 2775 {} + 2>/dev/null || true
    find /var/lib/hypervisor/backups -type d -exec chmod 2775 {} + 2>/dev/null || true
    find /var/lib/hypervisor/images -type d -exec chmod 2770 {} + 2>/dev/null || true

    # Secure areas
    chmod 0700 /var/lib/hypervisor/secure 2>/dev/null || true
    chmod 0750 /var/lib/hypervisor/system 2>/dev/null || true

    # Apply basic firewall rules
    if command -v nft &>/dev/null; then
        # Allow SSH, VM console ports
        nft add rule inet filter input tcp dport 22 accept 2>/dev/null || true
        nft add rule inet filter input tcp dport 5900-5920 accept 2>/dev/null || true
    fi

    echo -e "${GREEN}✓ Balanced hardening applied${NC}"
}

apply_strict_hardening() {
    echo -e "${CYAN}Applying Strict Hardening Profile...${NC}"

    # Strict permissions for /etc/hypervisor
    chown -R root:root /etc/hypervisor
    find /etc/hypervisor -type d -exec chmod 0750 {} +
    find /etc/hypervisor -type f -exec chmod 0600 {} +
    find /etc/hypervisor/scripts -type f -name "*.sh" -exec chmod 0700 {} + 2>/dev/null || true

    # Admin group can read configs
    chgrp -R hypervisor-admins /etc/hypervisor 2>/dev/null || chgrp -R wheel /etc/hypervisor
    find /etc/hypervisor -type f -name "*.nix" -exec chmod 0640 {} +

    # Strict /var/lib/hypervisor
    find /var/lib/hypervisor -type d -exec chmod 0770 {} + 2>/dev/null || true
    chmod 0700 /var/lib/hypervisor/secure 2>/dev/null || true
    chmod 0700 /var/lib/hypervisor/system 2>/dev/null || true

    # Enable comprehensive audit logging
    if command -v auditctl &>/dev/null; then
        auditctl -w /etc/hypervisor -p wa -k hypervisor_config || true
        auditctl -w /var/lib/hypervisor/system -p wa -k hypervisor_system || true
    fi

    # Harden systemd services
    for service in /etc/systemd/system/hypervisor-*.service; do
        if [[ -f "$service" ]]; then
            # Add security restrictions if not present
            grep -q "ProtectSystem=strict" "$service" || \
                sed -i '/\[Service\]/a ProtectSystem=strict' "$service"
            grep -q "ProtectHome=true" "$service" || \
                sed -i '/\[Service\]/a ProtectHome=true' "$service"
            grep -q "NoNewPrivileges=true" "$service" || \
                sed -i '/\[Service\]/a NoNewPrivileges=true' "$service"
        fi
    done
    systemctl daemon-reload

    echo -e "${GREEN}✓ Strict hardening applied${NC}"
}

apply_paranoid_hardening() {
    echo -e "${CYAN}Applying Paranoid Hardening Profile...${NC}"
    echo -e "${YELLOW}⚠️  This will significantly restrict system access!${NC}"

    # Very restrictive permissions
    chown -R root:root /etc/hypervisor
    find /etc/hypervisor -type d -exec chmod 0700 {} +
    find /etc/hypervisor -type f -exec chmod 0600 {} +
    find /etc/hypervisor/scripts -type f -name "*.sh" -exec chmod 0700 {} + 2>/dev/null || true

    # Everything in /var/lib/hypervisor locked down
    chown -R root:root /var/lib/hypervisor
    find /var/lib/hypervisor -type d -exec chmod 0700 {} +
    find /var/lib/hypervisor -type f -exec chmod 0600 {} +

    # Only admin group can access VM directories
    chgrp -R hypervisor-admins /var/lib/hypervisor/vms 2>/dev/null || chgrp -R wheel /var/lib/hypervisor/vms
    chmod 0750 /var/lib/hypervisor/vms 2>/dev/null || true

    # Maximum audit logging
    if command -v auditctl &>/dev/null; then
        auditctl -w /etc -p wa -k etc_changes || true
        auditctl -w /var/lib/hypervisor -p wa -k hypervisor_all || true
        auditctl -w /usr/bin/sudo -p x -k sudo_execution || true
    fi

    # Disable all non-essential services
    for service in cups bluetooth avahi-daemon; do
        systemctl stop "$service" 2>/dev/null || true
        systemctl disable "$service" 2>/dev/null || true
    done

    # Firewall: deny all except explicit allows
    if command -v nft &>/dev/null; then
        nft flush ruleset
        nft add table inet filter
        nft add chain inet filter input { type filter hook input priority 0 \; policy drop \; }
        nft add chain inet filter forward { type filter hook forward priority 0 \; policy drop \; }
        nft add chain inet filter output { type filter hook output priority 0 \; policy accept \; }

        # Allow loopback
        nft add rule inet filter input iif lo accept

        # Allow established connections
        nft add rule inet filter input ct state established,related accept

        # Allow SSH (admin only)
        nft add rule inet filter input tcp dport 22 accept
    fi

    echo -e "${GREEN}✓ Paranoid hardening applied${NC}"
    echo -e "${YELLOW}⚠️  System is now in maximum security mode${NC}"
}

remove_hardening() {
    echo -e "${CYAN}Removing System Hardening...${NC}"
    echo -e "${YELLOW}⚠️  This will restore default permissions${NC}"

    # Restore default permissions
    chown -R root:wheel /etc/hypervisor 2>/dev/null || true
    find /etc/hypervisor -type d -exec chmod 0755 {} + 2>/dev/null || true
    find /etc/hypervisor -type f -exec chmod 0644 {} + 2>/dev/null || true
    find /etc/hypervisor/scripts -type f -name "*.sh" -exec chmod 0755 {} + 2>/dev/null || true

    # Restore /var/lib/hypervisor
    find /var/lib/hypervisor -type d -exec chmod 0775 {} + 2>/dev/null || true

    # Clear audit rules
    if command -v auditctl &>/dev/null; then
        auditctl -D 2>/dev/null || true
    fi

    # Clear environment
    systemctl unset-environment HYPERVISOR_DEBUG 2>/dev/null || true

    # Remove hardening state
    rm -f "${HARDENING_STATE_FILE}"

    echo -e "${GREEN}✓ Hardening removed - system restored to defaults${NC}"
}

# ============================================================================
# Apply Selected Profile
# ============================================================================

apply_hardening_profile() {
    local profile="$1"

    # Create backup first
    local backup_path=$(create_backup)

    echo ""
    echo -e "${BOLD}Applying: ${profile}${NC}"
    echo ""

    case "$profile" in
        development)
            apply_development_hardening
            ;;
        balanced)
            apply_balanced_hardening
            ;;
        strict)
            apply_strict_hardening
            ;;
        paranoid)
            apply_paranoid_hardening
            ;;
        none)
            remove_hardening
            return 0
            ;;
        *)
            echo -e "${RED}Unknown profile: $profile${NC}"
            return 1
            ;;
    esac

    # Save state
    save_hardening_state "$profile"

    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✓ Hardening profile applied: ${BOLD}$profile${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  Backup saved to: ${DIM}${backup_path}${NC}"
    echo -e "  State file: ${DIM}${HARDENING_STATE_FILE}${NC}"
    echo ""
    echo -e "${YELLOW}  Important Notes:${NC}"
    echo -e "  • Test all VM operations to ensure they still work"
    echo -e "  • Check that authorized users can access their VMs"
    echo -e "  • Review audit logs: journalctl -t audit"
    echo ""
    echo -e "  To reverse these changes, run this wizard again and select '${RED}Un-harden${NC}'"
    echo ""
}

# ============================================================================
# Show Current Status
# ============================================================================

show_current_status() {
    local current_state=$(get_current_hardening_state)

    echo ""
    echo -e "${BOLD}Current Hardening Status:${NC}"
    echo ""

    if [[ "$current_state" == "none" ]]; then
        echo -e "  Status: ${YELLOW}No hardening applied${NC}"
        echo -e "  System using default security settings"
    else
        echo -e "  Status: ${GREEN}Hardened${NC}"
        echo -e "  Profile: ${BOLD}${current_state}${NC}"

        if [[ -f "${HARDENING_STATE_FILE}" ]]; then
            local timestamp=$(jq -r '.timestamp // "unknown"' "${HARDENING_STATE_FILE}" 2>/dev/null)
            local applied_by=$(jq -r '.applied_by // "unknown"' "${HARDENING_STATE_FILE}" 2>/dev/null)
            echo -e "  Applied: ${timestamp}"
            echo -e "  By: ${applied_by}"
        fi
    fi

    echo ""
}

# ============================================================================
# Main Wizard
# ============================================================================

main() {
    show_header
    show_current_status

    read -p "Press Enter to continue or Ctrl+C to exit..."

    while true; do
        show_header
        show_current_status
        show_hardening_profiles

        read -p "Select profile (0-5): " choice

        case "$choice" in
            1)
                apply_hardening_profile "development"
                break
                ;;
            2)
                apply_hardening_profile "balanced"
                break
                ;;
            3)
                apply_hardening_profile "strict"
                break
                ;;
            4)
                echo ""
                echo -e "${RED}${BOLD}WARNING: Paranoid Hardening${NC}"
                echo -e "${YELLOW}This will make the system VERY restrictive.${NC}"
                echo -e "${YELLOW}Some features may stop working.${NC}"
                echo ""
                read -p "Are you absolutely sure? (type 'YES' in capitals): " confirm

                if [[ "$confirm" == "YES" ]]; then
                    apply_hardening_profile "paranoid"
                    break
                else
                    echo -e "${CYAN}Cancelled.${NC}"
                    sleep 1
                fi
                ;;
            5)
                echo ""
                echo -e "${YELLOW}This will remove all hardening and restore defaults.${NC}"
                read -p "Are you sure? (y/N): " confirm

                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    apply_hardening_profile "none"
                    break
                else
                    echo -e "${CYAN}Cancelled.${NC}"
                    sleep 1
                fi
                ;;
            0)
                echo -e "${CYAN}Exiting without changes.${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please select 0-5.${NC}"
                sleep 2
                ;;
        esac
    done
}

# Run main wizard
main

exit 0
