#!/usr/bin/env bash
#
# fix-bash-source-pattern.sh - Fix unprotected BASH_SOURCE usage
# 
# This script audits and optionally fixes all scripts that use BASH_SOURCE
# without proper protection for piped execution.
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() { echo -e "${BLUE}==>${NC} $*"; }
print_success() { echo -e "${GREEN}✓${NC} $*"; }
print_error() { echo -e "${RED}✗${NC} $*"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $*"; }

# Get workspace root
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)"
cd "$WORKSPACE_ROOT"

# Counters
TOTAL_SCRIPTS=0
VULNERABLE_SCRIPTS=0
FIXED_SCRIPTS=0
DRY_RUN=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --fix)
            DRY_RUN=false
            shift
            ;;
        --help|-h)
            cat <<EOF
Usage: $0 [OPTIONS]

Audit and fix unprotected BASH_SOURCE usage in bash scripts.

OPTIONS:
    --fix       Actually fix the issues (default is dry-run)
    --help      Show this help message

WHAT IT CHECKS:
    1. Scripts using 'set -u' or 'set -euo pipefail'
    2. Unprotected BASH_SOURCE[0] usage (without :-default)
    3. Scripts that might be piped from curl

PATTERNS DETECTED:
    VULNERABLE:   \${BASH_SOURCE[0]:-$0}
    SAFE:         \${BASH_SOURCE[0]:-}
    SAFE:         \${BASH_SOURCE[0]:-default}

EOF
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

if $DRY_RUN; then
    print_warning "DRY RUN MODE - No changes will be made"
    print_warning "Use --fix to actually apply fixes"
    echo
fi

# Check if a script uses 'set -u'
uses_set_u() {
    local file="$1"
    grep -q -E '^set -[a-z]*u|^set -o nounset' "$file"
}

# Check if a script has unprotected BASH_SOURCE
has_unprotected_bash_source() {
    local file="$1"
    # Look for ${BASH_SOURCE[0]:-$0} without :- default
    # Pattern matches: ${BASH_SOURCE[0]:-$0} but NOT ${BASH_SOURCE[0]:-...}
    if grep -q 'BASH_SOURCE\[0\]' "$file"; then
        # Has BASH_SOURCE - now check if ANY usage is unprotected
        if grep 'BASH_SOURCE\[0\]' "$file" | grep -q -v ':-'; then
            return 0  # Found unprotected usage
        fi
    fi
    return 1  # No unprotected usage
}

# Check if script might be piped (installer, bootstrap, etc.)
might_be_piped() {
    local file="$1"
    local basename="$(basename "$file")"
    
    # Check for installer/bootstrap patterns
    if [[ "$basename" =~ install|bootstrap|setup ]]; then
        return 0
    fi
    
    # Check if documented as pipeable
    if head -20 "$file" | grep -q "curl.*|.*bash"; then
        return 0
    fi
    
    return 1
}

# Classify vulnerability
classify_vulnerability() {
    local file="$1"
    local set_u=false
    local unprotected=false
    local pipeable=false
    
    uses_set_u "$file" && set_u=true
    has_unprotected_bash_source "$file" && unprotected=true
    might_be_piped "$file" && pipeable=true
    
    if $set_u && $unprotected; then
        if $pipeable; then
            echo "CRITICAL"  # Will definitely break if piped
        else
            echo "HIGH"      # Will break if someone tries to pipe it
        fi
    elif $unprotected; then
        echo "LOW"          # Might break in edge cases
    else
        echo "SAFE"
    fi
}

# Create backup
create_backup() {
    local file="$1"
    cp "$file" "${file}.bak"
}

# Fix unprotected BASH_SOURCE usage
fix_bash_source() {
    local file="$1"
    local tmp_file="${file}.tmp"
    
    print_header "Fixing: $file"
    
    create_backup "$file"
    
    # Fix pattern: ${BASH_SOURCE[0]:-$0} -> ${BASH_SOURCE[0]:-}
    # Also fix: $BASH_SOURCE[0] -> ${BASH_SOURCE[0]:-}
    sed -E \
        -e 's/\$\{BASH_SOURCE\[0\]\}([^:-])/\$\{BASH_SOURCE\[0\]:-\}\1/g' \
        -e 's/\$BASH_SOURCE\[0\]/\$\{BASH_SOURCE\[0\]:-\}/g' \
        "$file" > "$tmp_file"
    
    # Additional fix for common patterns
    sed -i -E \
        -e 's/SCRIPT_DIR="\$\(cd "\$\(dirname "\$\{BASH_SOURCE\[0\]:-\}"\)" && pwd\)"/SCRIPT_DIR="\$\(cd "\$\(dirname "\$\{BASH_SOURCE\[0\]:-\$0\}"\)" \&\& pwd\)"/' \
        "$tmp_file"
    
    # Check if we actually changed anything
    if ! diff -q "$file" "$tmp_file" >/dev/null 2>&1; then
        mv "$tmp_file" "$file"
        print_success "Fixed patterns in $file"
        return 0
    else
        rm "$tmp_file"
        print_warning "No changes needed for $file"
        return 1
    fi
}

# Main audit
audit_scripts() {
    print_header "Auditing bash scripts for BASH_SOURCE vulnerabilities..."
    echo
    
    # Find all bash scripts
    while IFS= read -r -d '' script; do
        ((TOTAL_SCRIPTS++))
        
        # Skip backup files
        if [[ "$script" =~ \.bak$ ]]; then
            continue
        fi
        
        local vuln_level="$(classify_vulnerability "$script")"
        
        if [[ "$vuln_level" != "SAFE" ]]; then
            ((VULNERABLE_SCRIPTS++))
            
            local relative_path="${script#$WORKSPACE_ROOT/}"
            
            case "$vuln_level" in
                CRITICAL)
                    print_error "CRITICAL: $relative_path"
                    echo "           → Uses 'set -u' + unprotected BASH_SOURCE + might be piped"
                    ;;
                HIGH)
                    print_warning "HIGH:     $relative_path"
                    echo "           → Uses 'set -u' + unprotected BASH_SOURCE"
                    ;;
                LOW)
                    echo -e "${YELLOW}LOW:${NC}      $relative_path"
                    echo "           → Unprotected BASH_SOURCE (no set -u)"
                    ;;
            esac
            
            # Fix if requested
            if ! $DRY_RUN && [[ "$vuln_level" == "CRITICAL" || "$vuln_level" == "HIGH" ]]; then
                if fix_bash_source "$script"; then
                    ((FIXED_SCRIPTS++))
                fi
                echo
            fi
        fi
    done < <(find . -type f -name "*.sh" -print0)
    
    echo
    print_header "Audit Summary"
    echo "Total scripts scanned:    $TOTAL_SCRIPTS"
    echo "Vulnerable scripts found: $VULNERABLE_SCRIPTS"
    
    if ! $DRY_RUN; then
        echo "Scripts fixed:            $FIXED_SCRIPTS"
    fi
    
    echo
    
    if [[ $VULNERABLE_SCRIPTS -gt 0 ]]; then
        if $DRY_RUN; then
            print_warning "Run with --fix to automatically fix CRITICAL and HIGH severity issues"
        else
            print_success "Fixed $FIXED_SCRIPTS scripts"
            if [[ $FIXED_SCRIPTS -lt $VULNERABLE_SCRIPTS ]]; then
                print_warning "Some LOW severity issues remain - these are lower priority"
            fi
        fi
    else
        print_success "No vulnerabilities found!"
    fi
}

# Run audit
audit_scripts
