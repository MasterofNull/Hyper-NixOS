#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Example: Migrating a script to use shared libraries
# This shows the before and after of script migration
#

# ============================================================================
# BEFORE: Original script with duplicated code
# ============================================================================

original_script_example() {
    cat << 'ORIGINAL'
#!/usr/bin/env bash

# Color definitions (DUPLICATED)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function (DUPLICATED)
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Root check (DUPLICATED)
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root${NC}"
        exit 1
    fi
}

# System detection (DUPLICATED)
detect_system() {
    SYSTEM_RAM=$(($(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024))
    SYSTEM_CPUS=$(nproc)
}

# Main logic
main() {
    check_root
    detect_system
    
    echo -e "${GREEN}✓${NC} Starting installation..."
    log "System has ${SYSTEM_RAM}MB RAM and ${SYSTEM_CPUS} CPUs"
    
    if [[ $SYSTEM_RAM -lt 2048 ]]; then
        echo -e "${RED}✗${NC} Insufficient RAM"
        exit 1
    fi
    
    echo -e "${GREEN}✓${NC} Installation complete"
}

main "$@"
ORIGINAL
}

# ============================================================================
# AFTER: Migrated script using shared libraries
# ============================================================================

migrated_script_example() {
    cat << 'MIGRATED'
#!/usr/bin/env bash
#
# Example Installation Script
# Now using shared libraries for common functionality
#

# Source common libraries
source /etc/hypervisor/scripts/lib/common.sh || {
    echo "ERROR: Failed to load common library" >&2
    exit 1
}

# Script configuration
SCRIPT_NAME="example-installer"
REQUIRES_ROOT=true
MIN_RAM_MB=2048
MIN_CPUS=2

# Main logic (much cleaner!)
main() {
    # Initialize script with standard setup
    init_script "$SCRIPT_NAME" "$REQUIRES_ROOT"
    
    # Check system requirements
    print_header "System Requirements Check"
    if ! check_requirements "$MIN_RAM_MB" "$MIN_CPUS"; then
        print_error "System does not meet minimum requirements"
        exit 1
    fi
    
    # Show system summary
    print_section "System Information"
    get_system_summary
    
    # Installation logic
    print_section "Installation"
    print_info "Starting installation process..."
    
    # Use built-in retry mechanism
    retry_with_backoff 3 2 apt-get update || {
        print_error "Failed to update package lists"
        exit 1
    }
    
    # Show progress
    local steps=5
    for i in $(seq 1 $steps); do
        print_info "Processing step $i of $steps..."
        show_progress $i $steps
        sleep 1
    done
    
    print_success "Installation completed successfully!"
}

# Run main function
main "$@"
MIGRATED
}

# ============================================================================
# MIGRATION BENEFITS
# ============================================================================

show_benefits() {
    cat << 'BENEFITS'
Migration Benefits:

1. Code Reduction:
   - Original: ~50 lines
   - Migrated: ~35 lines (30% reduction)
   - Removed all color definitions
   - Removed custom logging
   - Removed system detection code

2. Consistency:
   - Standardized UI across all scripts
   - Consistent error handling
   - Uniform logging format

3. Enhanced Features:
   - Automatic logging setup
   - Built-in retry mechanisms
   - Progress indicators
   - System requirement checking
   - Graceful cleanup on exit

4. Maintainability:
   - Bug fixes in one place
   - Easy to add new features
   - Consistent behavior

5. Better User Experience:
   - Professional UI elements
   - Clear error messages
   - Progress feedback
   - Colored output
BENEFITS
}

# ============================================================================
# MIGRATION GUIDE
# ============================================================================

migration_steps() {
    cat << 'GUIDE'
Step-by-Step Migration Guide:

1. Add library sourcing at the top:
   ```bash
   source /etc/hypervisor/scripts/lib/common.sh || {
       echo "ERROR: Failed to load common library" >&2
       exit 1
   }
   ```

2. Remove duplicate code:
   - Delete color definitions
   - Delete logging functions
   - Delete root check functions
   - Delete system detection code

3. Replace with library functions:
   - log() → log_info(), log_error(), log_warn()
   - echo -e "${GREEN}✓${NC}" → print_success()
   - echo -e "${RED}✗${NC}" → print_error()
   - check_root() → init_script "name" true

4. Use enhanced features:
   - Add init_script() at start of main
   - Use check_requirements() for validation
   - Add retry_with_backoff() for network operations
   - Use show_progress() for long operations

5. Test thoroughly:
   - Verify all functionality works
   - Check log output
   - Test error conditions
   - Verify cleanup on exit
GUIDE
}

# Show examples
echo "=== Original Script Example ==="
original_script_example
echo
echo "=== Migrated Script Example ==="
migrated_script_example
echo
echo "=== Migration Benefits ==="
show_benefits
echo
echo "=== Migration Guide ==="
migration_steps