#!/usr/bin/env bash
# Secure Password Reset Tool
# Requires special authentication to reset passwords and update hash

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Configuration
readonly HASH_FILE="/var/lib/hypervisor/.credential-hash"
readonly TAMPER_FLAG="/var/lib/hypervisor/.tamper-detected"
readonly SECURITY_LOG="/var/log/hypervisor/security.log"
readonly RESET_TOKEN_FILE="/etc/hypervisor/.reset-token"

# Generate a reset token based on machine ID and date
generate_reset_token() {
    local machine_id=$(cat /etc/machine-id)
    local date_salt=$(date +%Y%m%d)
    echo -n "${machine_id}:${date_salt}:hypervisor-reset" | sha256sum | cut -d' ' -f1
}

# Verify physical presence
verify_physical_presence() {
    if [[ -n "${SSH_TTY:-}" ]]; then
        echo -e "${RED}ERROR: This operation requires physical console access${NC}"
        echo "Please run this command from the physical console (TTY1-TTY6)"
        return 1
    fi
    
    if ! tty -s || ! [[ "$(tty)" =~ ^/dev/tty[0-9]+$ ]]; then
        echo -e "${RED}ERROR: Not on a physical TTY${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Physical console access verified${NC}"
    return 0
}

# Verify administrator authentication
verify_admin_auth() {
    echo -e "${YELLOW}Administrator authentication required${NC}"
    echo
    
    # Method 1: Check for pre-generated reset token
    if [[ -f "$RESET_TOKEN_FILE" ]]; then
        local stored_token=$(cat "$RESET_TOKEN_FILE")
        echo "Enter password reset token:"
        read -rs entered_token
        
        if [[ "$entered_token" == "$stored_token" ]]; then
            echo -e "${GREEN}✓ Reset token verified${NC}"
            return 0
        fi
    fi
    
    # Method 2: Generate and verify daily token
    local expected_token=$(generate_reset_token)
    echo "Enter today's reset token (or press Enter for challenge):"
    read -rs entered_token
    
    if [[ "$entered_token" == "$expected_token" ]]; then
        echo -e "${GREEN}✓ Daily reset token verified${NC}"
        return 0
    fi
    
    # Method 3: Security challenge
    echo -e "${YELLOW}Security challenge required${NC}"
    echo "Answer the following to prove system ownership:"
    echo
    
    # Challenge 1: Machine ID
    echo "What are the first 8 characters of this machine's ID?"
    read -r machine_answer
    local machine_id=$(cat /etc/machine-id | cut -c1-8)
    
    if [[ "$machine_answer" != "$machine_id" ]]; then
        echo -e "${RED}Incorrect answer${NC}"
        return 1
    fi
    
    # Challenge 2: Installation date (from first file in /etc/nixos)
    local install_date=$(stat -c %y /etc/nixos/configuration.nix 2>/dev/null | cut -d' ' -f1)
    echo "What date was this system installed (YYYY-MM-DD)?"
    read -r date_answer
    
    if [[ "$date_answer" != "$install_date" ]]; then
        echo -e "${RED}Incorrect answer${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Security challenge passed${NC}"
    return 0
}

# Clear tamper flag if legitimate
clear_tamper_flag() {
    if [[ -f "$TAMPER_FLAG" ]]; then
        echo -e "${YELLOW}Clearing tamper detection flag...${NC}"
        mv "$TAMPER_FLAG" "${TAMPER_FLAG}.cleared-$(date +%Y%m%d-%H%M%S)"
        echo "Previous tamper flag archived"
    fi
}

# Reset user password
reset_user_password() {
    local username="$1"
    
    # Verify user exists
    if ! id "$username" &>/dev/null; then
        echo -e "${RED}User '$username' does not exist${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Resetting password for user: $username${NC}"
    
    # Temporarily unlock sudo configuration
    chattr -i /etc/sudoers.d/* 2>/dev/null || true
    
    # Reset the password
    if passwd "$username"; then
        echo -e "${GREEN}✓ Password reset successfully${NC}"
        
        # Update credential hash
        /run/current-system/sw/bin/verify-credentials update
        
        # Re-lock sudo configuration
        chattr +i /etc/sudoers.d/* 2>/dev/null || true
        
        # Log the action
        mkdir -p "$(dirname "$SECURITY_LOG")"
        echo "[$(date -Iseconds)] Password reset for $username by authorized administrator" >> "$SECURITY_LOG"
        
        return 0
    else
        echo -e "${RED}Failed to reset password${NC}"
        # Re-lock sudo configuration even on failure
        chattr +i /etc/sudoers.d/* 2>/dev/null || true
        return 1
    fi
}

# Main execution
main() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}           Hyper-NixOS Secure Password Reset Tool               ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo
    
    # Must run as root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This tool must be run as root${NC}"
        exit 1
    fi
    
    # Verify physical presence
    if ! verify_physical_presence; then
        exit 1
    fi
    
    # Verify administrator authentication
    if ! verify_admin_auth; then
        echo -e "${RED}Authentication failed${NC}"
        logger -p auth.crit "Failed password reset attempt from $(tty)"
        exit 1
    fi
    
    # Show current status
    echo
    echo "Current system status:"
    if [[ -f "$TAMPER_FLAG" ]]; then
        echo -e "${RED}⚠ Tamper detection flag is SET${NC}"
    else
        echo -e "${GREEN}✓ No tamper detection flag${NC}"
    fi
    
    if [[ -f "$HASH_FILE" ]]; then
        echo -e "${GREEN}✓ Credential hash exists${NC}"
    else
        echo -e "${YELLOW}⚠ No credential hash found${NC}"
    fi
    
    echo
    echo "Available actions:"
    echo "1) Reset user password"
    echo "2) Clear tamper flag (if legitimate)"
    echo "3) Regenerate credential hash"
    echo "4) View security log"
    echo "5) Exit"
    echo
    read -p "Select action [1-5]: " action
    
    case "$action" in
        1)
            echo
            echo "Current users with wheel access:"
            getent group wheel | cut -d: -f4 | tr ',' '\n' | while read user; do
                [[ -n "$user" && "$user" != "root" ]] && echo "  - $user"
            done
            echo
            read -p "Enter username to reset: " username
            reset_user_password "$username"
            ;;
        2)
            clear_tamper_flag
            ;;
        3)
            echo "Regenerating credential hash..."
            /run/current-system/sw/bin/verify-credentials update
            echo -e "${GREEN}✓ Credential hash updated${NC}"
            ;;
        4)
            echo "Recent security events:"
            tail -20 "$SECURITY_LOG" 2>/dev/null || echo "No security log found"
            ;;
        5)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid selection${NC}"
            exit 1
            ;;
    esac
    
    echo
    echo -e "${GREEN}Operation completed${NC}"
    logger -p auth.warning "Secure password reset tool used by administrator"
}

main "$@"