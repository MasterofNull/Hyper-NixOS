#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Security Phase Transition Script
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Manages transitions between setup (phase 1) and hardened (phase 2) security modes
#

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh" || {
    echo "ERROR: Failed to load common library" >&2
    exit 1
}
source "${SCRIPT_DIR}/lib/exit_codes.sh"

# Initialize logging
init_logging "phase_transition"

# Configuration
readonly PHASE1_MARKER="/etc/hypervisor/.phase1_setup"
readonly PHASE2_MARKER="/etc/hypervisor/.phase2_hardened"
readonly SETUP_COMPLETE_MARKER="/etc/hypervisor/.setup_complete"
readonly BACKUP_DIR="/var/lib/hypervisor/backups/phase-transitions"

# Color output for warnings
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Show current status
show_status() {
    local phase
    phase=$(get_security_phase)
    
    echo "=== Hyper-NixOS Security Phase Status ==="
    echo
    echo "Current Phase: ${phase^^}"
    echo
    
    case "$phase" in
        setup)
            echo "Mode: PERMISSIVE"
            echo "Description: Initial setup and configuration mode"
            echo
            echo "Allowed Operations:"
            echo "  ✓ All system configurations"
            echo "  ✓ Package installation"
            echo "  ✓ User management"
            echo "  ✓ Network configuration"
            echo "  ✓ Storage provisioning"
            echo
            echo -e "${YELLOW}Warning: System is in setup mode with elevated permissions${NC}"
            ;;
        hardened)
            echo "Mode: RESTRICTIVE"
            echo "Description: Production-ready hardened mode"
            echo
            echo "Allowed Operations:"
            echo "  ✓ VM start/stop/status"
            echo "  ✓ Backup operations"
            echo "  ✓ Monitoring and logs"
            echo "  ✗ System configuration (restricted)"
            echo "  ✗ User modifications (restricted)"
            echo
            echo -e "${GREEN}System is hardened for production use${NC}"
            ;;
    esac
    
    echo
    echo "Phase Markers:"
    [[ -f "$PHASE1_MARKER" ]] && echo "  Phase 1 marker: EXISTS"
    [[ -f "$PHASE2_MARKER" ]] && echo "  Phase 2 marker: EXISTS"
    [[ -f "$SETUP_COMPLETE_MARKER" ]] && echo "  Setup complete: YES"
}

# Pre-flight checks for phase 2
preflight_phase2() {
    local errors=0
    
    echo "=== Phase 2 Pre-flight Checks ==="
    echo
    
    # Check if setup is complete
    echo -n "Checking setup completion... "
    if [[ -f "$SETUP_COMPLETE_MARKER" ]]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        echo "  ERROR: Setup not marked as complete"
        echo "  Run: touch $SETUP_COMPLETE_MARKER"
        ((errors++))
    fi
    
    # Check critical services
    echo -n "Checking libvirtd service... "
    if systemctl is-active libvirtd >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        echo "  ERROR: libvirtd is not running"
        ((errors++))
    fi
    
    # Check file permissions
    echo -n "Checking file permissions... "
    local perm_issues=0
    find /etc/hypervisor -type f -perm /022 -print0 2>/dev/null | while IFS= read -r -d '' file; do
        ((perm_issues++))
    done
    if [[ $perm_issues -eq 0 ]]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠${NC}"
        echo "  WARNING: Some files have world-writable permissions"
    fi
    
    # Check disk space
    echo -n "Checking disk space... "
    local disk_usage
    disk_usage=$(df /var/lib/hypervisor | tail -1 | awk '{print int($5)}')
    if [[ $disk_usage -lt 90 ]]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠${NC}"
        echo "  WARNING: Disk usage is high ($disk_usage%)"
    fi
    
    # Check for running VMs
    echo -n "Checking for running VMs... "
    local running_vms
    running_vms=$(virsh list --name 2>/dev/null | grep -v '^$' | wc -l)
    echo "$running_vms running"
    if [[ $running_vms -gt 0 ]]; then
        echo "  INFO: $running_vms VMs are currently running"
    fi
    
    echo
    if [[ $errors -gt 0 ]]; then
        echo -e "${RED}Pre-flight checks failed with $errors error(s)${NC}"
        return 1
    else
        echo -e "${GREEN}All pre-flight checks passed${NC}"
        return 0
    fi
}

# Transition to phase 2 (hardened)
transition_to_phase2() {
    log_info "Starting transition to Phase 2 (Hardened Mode)"
    
    # Run pre-flight checks
    if ! preflight_phase2; then
        die "Pre-flight checks failed. Fix issues before transitioning."
    fi
    
    # Confirmation
    echo
    echo -e "${YELLOW}=== IMPORTANT SECURITY NOTICE ===${NC}"
    echo
    echo "You are about to transition to HARDENED MODE."
    echo "This will:"
    echo "  • Remove administrative privileges from services"
    echo "  • Restrict system modification capabilities"
    echo "  • Enable strict security policies"
    echo "  • Make configuration files read-only"
    echo "  • Disable interactive setup features"
    echo
    echo "This action is REVERSIBLE but will require authentication."
    echo
    read -p "Type 'HARDEN' to confirm: " confirmation
    
    if [[ "$confirmation" != "HARDEN" ]]; then
        echo "Transition cancelled."
        exit 0
    fi
    
    # Create backup
    echo
    echo "Creating configuration backup..."
    mkdir -p "$BACKUP_DIR"
    local backup_name="phase1-backup-$(date +%Y%m%d-%H%M%S)"
    tar czf "$BACKUP_DIR/$backup_name.tar.gz" \
        /etc/hypervisor \
        "$PHASE1_MARKER" \
        2>/dev/null || true
    echo "Backup saved to: $BACKUP_DIR/$backup_name.tar.gz"
    
    # Apply hardening
    echo
    echo "Applying security hardening..."
    
    # 1. Tighten file permissions
    echo -n "  Setting restrictive file permissions... "
    find /etc/hypervisor -type f -exec chmod 640 {} \;
    find /etc/hypervisor -type d -exec chmod 750 {} \;
    find /etc/hypervisor/scripts -name "*.sh" -exec chmod 750 {} \;
    chown -R root:hypervisor /etc/hypervisor
    echo -e "${GREEN}✓${NC}"
    
    # 2. Remove setup artifacts
    echo -n "  Removing setup artifacts... "
    rm -f "$PHASE1_MARKER"
    rm -rf /tmp/hypervisor-setup-*
    rm -f /var/lib/hypervisor/.first_boot_welcome_shown
    echo -e "${GREEN}✓${NC}"
    
    # 3. Disable setup services
    echo -n "  Disabling setup services... "
    systemctl disable hypervisor-setup-wizard.service 2>/dev/null || true
    systemctl disable hypervisor-first-boot.service 2>/dev/null || true
    systemctl stop hypervisor-setup-wizard.service 2>/dev/null || true
    echo -e "${GREEN}✓${NC}"
    
    # 4. Create phase 2 marker
    echo -n "  Creating phase 2 marker... "
    touch "$PHASE2_MARKER"
    chmod 644 "$PHASE2_MARKER"
    echo -e "${GREEN}✓${NC}"
    
    # 5. Apply SELinux/AppArmor policies if available
    if command -v getenforce >/dev/null 2>&1; then
        echo -n "  Enabling SELinux enforcing mode... "
        setenforce 1 2>/dev/null && echo -e "${GREEN}✓${NC}" || echo -e "${YELLOW}⚠ (failed)${NC}"
    fi
    
    if command -v aa-enforce >/dev/null 2>&1; then
        echo -n "  Enforcing AppArmor profiles... "
        aa-enforce /etc/apparmor.d/hypervisor.* 2>/dev/null && echo -e "${GREEN}✓${NC}" || echo -e "${YELLOW}⚠ (not found)${NC}"
    fi
    
    # 6. Reload services with new permissions
    echo -n "  Reloading services... "
    systemctl daemon-reload
    systemctl restart hypervisor-menu.service 2>/dev/null || true
    systemctl restart hypervisor-api.service 2>/dev/null || true
    echo -e "${GREEN}✓${NC}"
    
    # Success message
    echo
    echo -e "${GREEN}=== Phase 2 Hardening Complete ===${NC}"
    echo
    echo "System is now in PRODUCTION MODE with restricted permissions."
    echo
    echo "To rollback to setup mode, run:"
    echo "  sudo $0 rollback"
    echo
    
    log_info "Successfully transitioned to Phase 2"
}

# Rollback to phase 1 (setup)
rollback_to_phase1() {
    log_info "Starting rollback to Phase 1 (Setup Mode)"
    
    # Require sudo authentication
    if [[ $EUID -ne 0 ]]; then
        die "Rollback requires root privileges. Run with sudo."
    fi
    
    # Confirmation
    echo
    echo -e "${YELLOW}=== SECURITY ROLLBACK WARNING ===${NC}"
    echo
    echo "You are about to rollback to SETUP MODE."
    echo "This will:"
    echo "  • Re-enable administrative privileges"
    echo "  • Allow system modifications"
    echo "  • Relax security policies"
    echo "  • Enable configuration changes"
    echo
    echo -e "${RED}This reduces system security!${NC}"
    echo
    read -p "Type 'ROLLBACK' to confirm: " confirmation
    
    if [[ "$confirmation" != "ROLLBACK" ]]; then
        echo "Rollback cancelled."
        exit 0
    fi
    
    echo
    echo "Rolling back to setup mode..."
    
    # 1. Remove hardening marker
    echo -n "  Removing phase 2 marker... "
    rm -f "$PHASE2_MARKER"
    echo -e "${GREEN}✓${NC}"
    
    # 2. Create setup marker
    echo -n "  Creating phase 1 marker... "
    touch "$PHASE1_MARKER"
    chmod 644 "$PHASE1_MARKER"
    echo -e "${GREEN}✓${NC}"
    
    # 3. Relax permissions
    echo -n "  Relaxing file permissions... "
    find /etc/hypervisor -type f -exec chmod 644 {} \;
    find /etc/hypervisor -type d -exec chmod 755 {} \;
    find /etc/hypervisor/scripts -name "*.sh" -exec chmod 755 {} \;
    echo -e "${GREEN}✓${NC}"
    
    # 4. Re-enable setup services
    echo -n "  Re-enabling setup services... "
    systemctl enable hypervisor-setup-wizard.service 2>/dev/null || true
    echo -e "${GREEN}✓${NC}"
    
    # 5. Relax SELinux/AppArmor if present
    if command -v getenforce >/dev/null 2>&1; then
        echo -n "  Setting SELinux to permissive... "
        setenforce 0 2>/dev/null && echo -e "${GREEN}✓${NC}" || echo -e "${YELLOW}⚠ (failed)${NC}"
    fi
    
    if command -v aa-complain >/dev/null 2>&1; then
        echo -n "  Setting AppArmor to complain mode... "
        aa-complain /etc/apparmor.d/hypervisor.* 2>/dev/null && echo -e "${GREEN}✓${NC}" || echo -e "${YELLOW}⚠ (not found)${NC}"
    fi
    
    # 6. Reload services
    echo -n "  Reloading services... "
    systemctl daemon-reload
    systemctl restart hypervisor-menu.service 2>/dev/null || true
    systemctl restart hypervisor-api.service 2>/dev/null || true
    echo -e "${GREEN}✓${NC}"
    
    # Success message
    echo
    echo -e "${GREEN}=== Rollback Complete ===${NC}"
    echo
    echo "System is now in SETUP MODE."
    echo -e "${YELLOW}Remember to harden the system when setup is complete:${NC}"
    echo "  $0 harden"
    echo
    
    log_info "Successfully rolled back to Phase 1"
}

# Show usage
usage() {
    cat <<EOF
Usage: $(basename "$0") [COMMAND]

Security phase transition management for Hyper-NixOS

Commands:
    status      Show current security phase status (default)
    harden      Transition to phase 2 (hardened/production mode)
    rollback    Rollback to phase 1 (setup mode) [requires root]
    check       Run pre-flight checks for phase 2
    help        Show this help message

Current phase: $(get_security_phase)

Examples:
    # Check current status
    $(basename "$0") status
    
    # Transition to hardened mode
    $(basename "$0") harden
    
    # Rollback to setup mode
    sudo $(basename "$0") rollback

For more information, see:
    /etc/hypervisor/docs/TWO_PHASE_SECURITY_MODEL.md

EOF
}

# Main command handler
main() {
    local command="${1:-status}"
    
    case "$command" in
        status)
            show_status
            ;;
        harden|phase2)
            transition_to_phase2
            ;;
        rollback|phase1|setup)
            rollback_to_phase1
            ;;
        check|preflight)
            preflight_phase2
            ;;
        help|-h|--help)
            usage
            ;;
        *)
            echo "Unknown command: $command"
            echo
            usage
            exit $EXIT_INVALID_ARGUMENT
            ;;
    esac
}

# Run main function
main "$@"