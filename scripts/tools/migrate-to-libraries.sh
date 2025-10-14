#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Hyper-NixOS Script Migration Tool
# Helps migrate scripts to use shared libraries
#

# Use the new libraries ourselves!
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Try to load from project directory first
if [[ -f "$PROJECT_ROOT/scripts/lib/common.sh" ]]; then
    source "$PROJECT_ROOT/scripts/lib/common.sh"
elif [[ -f "/etc/hypervisor/scripts/lib/common.sh" ]]; then
    source "/etc/hypervisor/scripts/lib/common.sh"
else
    echo "ERROR: Cannot load common library" >&2
    echo "Continuing with basic functionality..." >&2
    # Define minimal functions needed
    print_error() { echo "ERROR: $*" >&2; }
    print_info() { echo "INFO: $*"; }
    print_success() { echo "SUCCESS: $*"; }
    print_warning() { echo "WARNING: $*"; }
    confirm() { 
        read -r -p "$1 [y/N]: " response
        [[ "$response" =~ ^[Yy]$ ]]
    }
fi

# Initialize (if function exists)
if command -v init_script >/dev/null 2>&1; then
    init_script "migrate-to-libraries" false
fi

# Configuration
DRY_RUN=false
BACKUP=true
SCRIPTS_DIR="${1:-.}"

# Patterns to detect
declare -A PATTERNS=(
    ["colors"]="^(RED|GREEN|YELLOW|BLUE|CYAN|BOLD|NC)="
    ["logging"]="^(log|msg|error|warn|success|info)\(\)\s*\{"
    ["root_check"]="check_root|require_root"
    ["system_detect"]="SYSTEM_RAM=|SYSTEM_CPUS=|detect_system"
)

# Usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [DIRECTORY]

Migrate Hyper-NixOS scripts to use shared libraries.

Options:
    -n, --dry-run     Show what would be done without making changes
    -b, --no-backup   Don't create backups (not recommended)
    -h, --help        Show this help message

Arguments:
    DIRECTORY         Directory to scan for scripts (default: current directory)

Example:
    $0 /etc/hypervisor/scripts
    $0 --dry-run ./scripts

EOF
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -b|--no-backup)
                BACKUP=false
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                SCRIPTS_DIR="$1"
                shift
                ;;
        esac
    done
}

# Analyze a script for migration potential
analyze_script() {
    local script="$1"
    local issues=()
    
    # Skip if already using libraries
    if grep -q "source.*lib/common.sh" "$script"; then
        return 1
    fi
    
    # Check for patterns
    for pattern_name in "${!PATTERNS[@]}"; do
        if grep -qE "${PATTERNS[$pattern_name]}" "$script"; then
            issues+=("$pattern_name")
        fi
    done
    
    if [[ ${#issues[@]} -gt 0 ]]; then
        echo "${issues[@]}"
        return 0
    fi
    
    return 1
}

# Generate migration patch
generate_patch() {
    local script="$1"
    local temp_file="${script}.migrated"
    
    cp "$script" "$temp_file"
    
    # Add library sourcing after shebang
    sed -i '1a\\n# Source common libraries\nsource /etc/hypervisor/scripts/lib/common.sh || {\n    echo "ERROR: Failed to load common library" >&2\n    exit 1\n}\n' "$temp_file"
    
    # Comment out color definitions
    sed -i 's/^RED=.*$/# &  # MIGRATED: Use colors from ui.sh/' "$temp_file"
    sed -i 's/^GREEN=.*$/# &  # MIGRATED: Use colors from ui.sh/' "$temp_file"
    sed -i 's/^YELLOW=.*$/# &  # MIGRATED: Use colors from ui.sh/' "$temp_file"
    sed -i 's/^BLUE=.*$/# &  # MIGRATED: Use colors from ui.sh/' "$temp_file"
    sed -i 's/^CYAN=.*$/# &  # MIGRATED: Use colors from ui.sh/' "$temp_file"
    sed -i 's/^BOLD=.*$/# &  # MIGRATED: Use colors from ui.sh/' "$temp_file"
    sed -i 's/^NC=.*$/# &  # MIGRATED: Use colors from ui.sh/' "$temp_file"
    
    # Add migration comments for functions
    sed -i 's/^log()/# MIGRATED: Use log_info() from common.sh\n# &/' "$temp_file"
    sed -i 's/^error()/# MIGRATED: Use log_error() or print_error() from libraries\n# &/' "$temp_file"
    sed -i 's/^warn()/# MIGRATED: Use log_warn() or print_warning() from libraries\n# &/' "$temp_file"
    
    # Show diff
    if command -v diff >/dev/null 2>&1; then
        diff -u "$script" "$temp_file" || true
    fi
    
    echo "$temp_file"
}

# Migrate a single script
migrate_script() {
    local script="$1"
    
    print_section "Migrating: $script"
    
    # Analyze
    local issues
    if ! issues=$(analyze_script "$script"); then
        print_info "Already migrated or no issues found"
        return 0
    fi
    
    print_warning "Found issues: $issues"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "Would migrate this script (dry-run mode)"
        generate_patch "$script" >/dev/null
        return 0
    fi
    
    # Create backup
    if [[ "$BACKUP" == "true" ]]; then
        local backup_file
        backup_file=$(backup_file "$script") || {
            print_error "Failed to backup $script"
            return 1
        }
        print_success "Backed up to: $backup_file"
    fi
    
    # Generate and apply patch
    local migrated_file
    migrated_file=$(generate_patch "$script")
    
    if confirm "Apply migration to $script?"; then
        mv "$migrated_file" "$script"
        print_success "Migrated successfully"
        
        # Add execution bit if needed
        [[ -x "$backup_file" ]] && chmod +x "$script"
    else
        rm -f "$migrated_file"
        print_info "Skipped migration"
    fi
}

# Find and process scripts
find_scripts() {
    local dir="$1"
    
    print_header "Scanning for scripts in: $dir"
    
    local scripts=()
    while IFS= read -r -d '' script; do
        # Skip library files and non-bash scripts
        if [[ "$script" =~ /lib/ ]] || ! grep -q "^#!/.*bash" "$script" 2>/dev/null; then
            continue
        fi
        scripts+=("$script")
    done < <(find "$dir" -type f -name "*.sh" -print0 2>/dev/null)
    
    print_info "Found ${#scripts[@]} bash scripts"
    
    local migrated=0
    local skipped=0
    
    for script in "${scripts[@]}"; do
        if analyze_script "$script" >/dev/null 2>&1; then
            migrate_script "$script"
            ((migrated++))
        else
            ((skipped++))
        fi
    done
    
    print_section "Summary"
    print_info "Scripts analyzed: ${#scripts[@]}"
    print_success "Scripts migrated: $migrated"
    print_info "Scripts skipped: $skipped"
}

# Generate migration report
generate_report() {
    local dir="$1"
    local report_file="migration-report-$(date +%Y%m%d-%H%M%S).txt"
    
    print_header "Migration Analysis Report" > "$report_file"
    
    find "$dir" -type f -name "*.sh" -print0 2>/dev/null | while IFS= read -r -d '' script; do
        if [[ "$script" =~ /lib/ ]]; then
            continue
        fi
        
        if issues=$(analyze_script "$script" 2>/dev/null); then
            echo "Script: $script" >> "$report_file"
            echo "Issues: $issues" >> "$report_file"
            echo "---" >> "$report_file"
        fi
    done
    
    print_success "Report saved to: $report_file"
}

# Main function
main() {
    parse_args "$@"
    
    # Verify directory exists
    if [[ ! -d "$SCRIPTS_DIR" ]]; then
        print_error "Directory not found: $SCRIPTS_DIR"
        exit 1
    fi
    
    print_header "Hyper-NixOS Script Migration Tool"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "Running in DRY-RUN mode - no changes will be made"
    fi
    
    # Check if libraries exist
    local lib_path="${PROJECT_ROOT}/scripts/lib/common.sh"
    if [[ ! -f "$lib_path" ]] && [[ ! -f "/etc/hypervisor/scripts/lib/common.sh" ]]; then
        print_error "Common library not found"
        print_info "Please ensure shared libraries are installed first"
        exit 1
    fi
    
    # Process scripts
    find_scripts "$SCRIPTS_DIR"
    
    # Generate report
    if confirm "Generate detailed migration report?"; then
        generate_report "$SCRIPTS_DIR"
    fi
    
    print_success "Migration process completed!"
}

# Run main
main "$@"