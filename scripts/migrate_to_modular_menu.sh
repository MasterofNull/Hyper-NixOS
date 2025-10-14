#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Migrate to Modular Menu System
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Migrates from monolithic menu.sh to modular menu system
#

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh" || {
    echo "ERROR: Failed to load common library" >&2
    exit 1
}
source "${SCRIPT_DIR}/lib/exit_codes.sh"

# Initialize logging
init_logging "menu_migration"

# Configuration
readonly OLD_MENU="$SCRIPT_DIR/menu.sh"
readonly NEW_MENU="$SCRIPT_DIR/menu/menu.sh"
readonly BACKUP_DIR="$SCRIPT_DIR/backups"

# Main migration function
main() {
    log_info "Starting menu system migration"
    
    # Check if old menu exists
    if [[ ! -f "$OLD_MENU" ]]; then
        log_error "Old menu.sh not found at: $OLD_MENU"
        exit_with_error $EXIT_FILE_NOT_FOUND "Old menu system not found"
    fi
    
    # Check if new menu exists
    if [[ ! -f "$NEW_MENU" ]]; then
        log_error "New modular menu not found at: $NEW_MENU"
        exit_with_error $EXIT_FILE_NOT_FOUND "New menu system not found"
    fi
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Backup old menu
    local backup_name="menu.sh.backup.$(date +%Y%m%d_%H%M%S)"
    log_info "Backing up old menu to: $BACKUP_DIR/$backup_name"
    cp -p "$OLD_MENU" "$BACKUP_DIR/$backup_name"
    
    # Create symlink from old location to new
    log_info "Creating compatibility symlink"
    rm -f "$OLD_MENU"
    ln -s "menu/menu.sh" "$OLD_MENU"
    
    # Make new menu executable
    chmod +x "$NEW_MENU"
    chmod +x "$SCRIPT_DIR/menu/lib/"*.sh
    chmod +x "$SCRIPT_DIR/menu/modules/"*.sh
    
    # Update systemd service if needed
    if systemctl is-enabled hypervisor-menu.service &>/dev/null; then
        log_info "Menu service is enabled, restart may be required"
        echo "Note: You may need to restart the hypervisor-menu service:"
        echo "  sudo systemctl restart hypervisor-menu"
    fi
    
    # Test new menu
    log_info "Testing new menu system..."
    if "$NEW_MENU" --version &>/dev/null; then
        log_info "New menu system appears functional"
    else
        log_warn "Could not verify new menu system"
    fi
    
    log_info "Migration completed successfully"
    echo "Menu system has been migrated to modular structure."
    echo "Old menu backed up to: $BACKUP_DIR/$backup_name"
    echo ""
    echo "Benefits of the new modular system:"
    echo "- Easier maintenance and updates"
    echo "- Better code organization"
    echo "- Improved testability"
    echo "- Smaller, focused modules"
    
    exit $EXIT_SUCCESS
}

# Run main function
main "$@"