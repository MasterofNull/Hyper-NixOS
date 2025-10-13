#!/usr/bin/env bash
#
# Hyper-NixOS Script Validation Tool
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Validates all scripts for best practices, syntax, and standards compliance
#

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh" || {
    echo "ERROR: Failed to load common library" >&2
    exit 1
}
source "${SCRIPT_DIR}/lib/exit_codes.sh"

# Initialize logging
init_logging "script_validation"

# Configuration
VALIDATION_ERRORS=0
VALIDATION_WARNINGS=0
SCRIPTS_CHECKED=0
SCRIPTS_PASSED=0

# Colors for output (if terminal supports it)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Helper functions
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC}  $1"
    ((VALIDATION_WARNINGS++))
}

print_error() {
    echo -e "${RED}✗${NC} $1"
    ((VALIDATION_ERRORS++))
}

# Validation functions
validate_shebang() {
    local script="$1"
    local first_line
    first_line=$(head -n1 "$script")
    
    if [[ "$first_line" != "#!/usr/bin/env bash" ]]; then
        print_error "$script: Invalid shebang (expected: #!/usr/bin/env bash)"
        return 1
    fi
    return 0
}

validate_copyright() {
    local script="$1"
    
    if ! grep -q "Copyright.*MasterofNull" "$script"; then
        print_warning "$script: Missing copyright header"
        return 1
    fi
    return 0
}

validate_set_options() {
    local script="$1"
    
    # Check for strict error handling
    if ! grep -q "set -[Ee].*u.*o pipefail" "$script"; then
        print_error "$script: Missing strict error handling (set -Eeuo pipefail)"
        return 1
    fi
    return 0
}

validate_common_lib() {
    local script="$1"
    local script_name
    script_name=$(basename "$script")
    
    # Skip validation for common.sh itself and exit_codes.sh
    if [[ "$script_name" == "common.sh" || "$script_name" == "exit_codes.sh" ]]; then
        return 0
    fi
    
    if ! grep -q "source.*common.sh" "$script"; then
        print_warning "$script: Not using common library"
        return 1
    fi
    return 0
}

validate_shellcheck() {
    local script="$1"
    local output
    
    if ! command -v shellcheck >/dev/null 2>&1; then
        print_warning "ShellCheck not installed - skipping syntax validation"
        return 0
    fi
    
    if output=$(shellcheck -x "$script" 2>&1); then
        return 0
    else
        print_error "$script: ShellCheck found issues:"
        echo "$output" | sed 's/^/    /'
        return 1
    fi
}

validate_help_function() {
    local script="$1"
    
    # Check for usage or help function
    if ! grep -qE "(usage\(\)|show_help\(\)|--help)" "$script"; then
        print_warning "$script: No help/usage function found"
        return 1
    fi
    return 0
}

validate_logging() {
    local script="$1"
    local script_name
    script_name=$(basename "$script")
    
    # Skip for library files
    if [[ "$script_name" == "common.sh" || "$script_name" == "exit_codes.sh" ]]; then
        return 0
    fi
    
    # Check for logging initialization
    if ! grep -q "init_logging\|log_info\|log_error" "$script"; then
        print_warning "$script: No logging detected"
        return 1
    fi
    return 0
}

validate_exit_codes() {
    local script="$1"
    local script_name
    script_name=$(basename "$script")
    
    # Skip for library files
    if [[ "$script_name" == "common.sh" || "$script_name" == "exit_codes.sh" ]]; then
        return 0
    fi
    
    # Check if exit_codes.sh is sourced
    if grep -q "source.*exit_codes.sh" "$script"; then
        # Check for standardized exit codes
        if grep -qE "exit [0-9]+" "$script" | grep -vE "exit \\\$EXIT_|exit 0"; then
            print_warning "$script: Using numeric exit codes instead of constants"
            return 1
        fi
    fi
    return 0
}

validate_script() {
    local script="$1"
    local script_name
    script_name=$(basename "$script")
    local all_passed=true
    
    echo -e "\n${BLUE}Checking:${NC} $script"
    
    # Run all validations
    validate_shebang "$script" || all_passed=false
    validate_copyright "$script" || all_passed=false
    validate_set_options "$script" || all_passed=false
    validate_common_lib "$script" || all_passed=false
    validate_help_function "$script" || all_passed=false
    validate_logging "$script" || all_passed=false
    validate_exit_codes "$script" || all_passed=false
    validate_shellcheck "$script" || all_passed=false
    
    ((SCRIPTS_CHECKED++))
    
    if [[ "$all_passed" == "true" ]]; then
        print_success "$script_name: All checks passed"
        ((SCRIPTS_PASSED++))
    fi
}

# Main execution
main() {
    print_header "Hyper-NixOS Script Validation"
    echo "Validating all scripts for best practices and standards compliance..."
    
    # Check if ShellCheck is available
    if command -v shellcheck >/dev/null 2>&1; then
        echo "ShellCheck version: $(shellcheck --version | grep version: | awk '{print $2}')"
    else
        print_warning "ShellCheck not installed - syntax validation will be skipped"
        echo "Install with: nix-env -iA nixos.shellcheck"
    fi
    
    print_header "Script Validation"
    
    # Find and validate all shell scripts
    while IFS= read -r -d '' script; do
        validate_script "$script"
    done < <(find "$SCRIPT_DIR" -name "*.sh" -type f -print0 | sort -z)
    
    # Summary
    print_header "Validation Summary"
    echo "Scripts checked: $SCRIPTS_CHECKED"
    echo "Scripts passed all checks: $SCRIPTS_PASSED"
    echo -e "Errors: ${RED}$VALIDATION_ERRORS${NC}"
    echo -e "Warnings: ${YELLOW}$VALIDATION_WARNINGS${NC}"
    
    # Documentation check
    print_header "Documentation Check"
    echo "Checking for undocumented scripts..."
    
    local undocumented=0
    while IFS= read -r -d '' script; do
        script_name=$(basename "$script")
        if ! grep -q "$script_name" "${SCRIPT_DIR}/../docs/reference/SCRIPT_REFERENCE.md" 2>/dev/null; then
            print_warning "$script_name: Not documented in SCRIPT_REFERENCE.md"
            ((undocumented++))
        fi
    done < <(find "$SCRIPT_DIR" -name "*.sh" -type f -print0)
    
    if [[ $undocumented -eq 0 ]]; then
        print_success "All scripts are documented"
    else
        echo "Undocumented scripts: $undocumented"
    fi
    
    # Final result
    print_header "Final Result"
    if [[ $VALIDATION_ERRORS -eq 0 ]]; then
        if [[ $VALIDATION_WARNINGS -eq 0 ]]; then
            print_success "All validations passed!"
            exit $EXIT_SUCCESS
        else
            print_warning "Validation completed with warnings"
            exit $EXIT_SUCCESS
        fi
    else
        print_error "Validation failed with $VALIDATION_ERRORS errors"
        exit $EXIT_GENERAL_ERROR
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Validates all Hyper-NixOS scripts for best practices and standards compliance.

Options:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    --fix           Attempt to fix common issues (coming soon)

Checks performed:
    - Shebang validation
    - Copyright headers
    - Error handling (set -Eeuo pipefail)
    - Common library usage
    - Help/usage functions
    - Logging practices
    - Exit code standardization
    - ShellCheck syntax validation
    - Documentation coverage

Exit codes:
    0 - All checks passed (warnings allowed)
    1 - One or more errors found

EOF
            exit $EXIT_SUCCESS
            ;;
        -v|--verbose)
            DEBUG=true
            shift
            ;;
        --fix)
            echo "Auto-fix feature coming soon!"
            exit $EXIT_SUCCESS
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit $EXIT_INVALID_ARGUMENT
            ;;
    esac
done

# Run main validation
main