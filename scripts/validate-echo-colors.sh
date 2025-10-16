#!/usr/bin/env bash
#
# Color Echo Validation Script
# 
# Detects echo commands with ANSI color codes that are missing the -e flag
# This prevents escape codes from displaying as literal text
#
# Usage:
#   ./scripts/validate-echo-colors.sh              # Check all scripts
#   ./scripts/validate-echo-colors.sh --fix        # Auto-fix issues
#   ./scripts/validate-echo-colors.sh --ci         # CI mode (exit 1 on errors)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Counters
total_files=0
files_with_issues=0
total_issues=0
fixed_issues=0

# Modes
FIX_MODE=false
CI_MODE=false

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --fix) FIX_MODE=true ;;
        --ci) CI_MODE=true ;;
        --help|-h)
            echo "Color Echo Validation Script"
            echo
            echo "Usage:"
            echo "  $0              # Check all scripts"
            echo "  $0 --fix        # Auto-fix issues"
            echo "  $0 --ci         # CI mode (exit 1 on errors)"
            echo
            echo "This script detects echo commands with ANSI color codes"
            echo "that are missing the -e flag, which causes escape codes"
            echo "to display as literal text instead of rendering colors."
            exit 0
            ;;
    esac
done

# Banner
if [[ "$CI_MODE" != "true" ]]; then
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}          ${BOLD}Color Echo Validation Script${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
fi

# Get workspace root
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$WORKSPACE_ROOT"

# Patterns to detect
# Match: echo "..." with ${COLOR} or ${NC} but NOT echo -e "..."
PATTERN='echo[[:space:]]+"[^"]*\$\{[A-Z_]*\}'

# Function to check a single file
check_file() {
    local file="$1"
    local issues=0
    local line_numbers=()
    
    # Find lines with echo "..." containing color codes but missing -e
    while IFS= read -r line; do
        # Skip if it's already echo -e
        if echo "$line" | grep -q 'echo[[:space:]]*-e[[:space:]]*"'; then
            continue
        fi
        
        # Check if it contains echo "..." with color variables
        if echo "$line" | grep -qE 'echo[[:space:]]+"[^"]*\$\{[A-Z_]*\}'; then
            ((issues++)) || true
            line_numbers+=("$line")
        fi
    done < <(grep -n 'echo.*\${.*}' "$file" 2>/dev/null || true)
    
    if [[ $issues -gt 0 ]]; then
        ((files_with_issues++)) || true
        ((total_issues += issues)) || true
        
        if [[ "$CI_MODE" != "true" ]]; then
            echo -e "${YELLOW}⚠${NC} ${BOLD}$file${NC} - ${RED}$issues issue(s)${NC}"
            
            # Show first 5 problematic lines
            local count=0
            for line_info in "${line_numbers[@]}"; do
                if [[ $count -ge 5 ]]; then
                    echo -e "    ${CYAN}... and $((issues - 5)) more${NC}"
                    break
                fi
                echo -e "    ${BLUE}Line:${NC} $line_info"
                ((count++)) || true
            done
            echo
        fi
        
        # Fix if requested
        if [[ "$FIX_MODE" == "true" ]]; then
            fix_file "$file"
        fi
        
        return 1
    fi
    
    return 0
}

# Function to fix a file
fix_file() {
    local file="$1"
    local backup="${file}.backup-$(date +%s)"
    
    # Create backup
    cp "$file" "$backup"
    
    # Fix: Replace 'echo "...' with 'echo -e "...' when it contains color codes
    # Only fix lines that have echo "..." with ${...} color variables
    sed -i 's/\(^[[:space:]]*\)echo[[:space:]]\+"\([^"]*\${[A-Z_]*}[^"]*\)"/\1echo -e "\2"/g' "$file"
    
    # Count fixes
    local fixes=$(diff -u "$backup" "$file" | grep -c '^-[[:space:]]*echo[[:space:]]*"' || true)
    
    if [[ $fixes -gt 0 ]]; then
        ((fixed_issues += fixes)) || true
        echo -e "  ${GREEN}✓${NC} Fixed $fixes issue(s) in $file"
        rm "$backup"
    else
        # No changes made, restore backup
        mv "$backup" "$file"
    fi
}

# Find all shell scripts
echo -e "${BLUE}→${NC} Searching for shell scripts..."

# Check install.sh
if [[ -f "install.sh" ]]; then
    ((total_files++)) || true
    check_file "install.sh" || true
fi

# Check all scripts in scripts/ directory
if [[ -d "scripts" ]]; then
    while IFS= read -r file; do
        ((total_files++)) || true
        check_file "$file" || true
    done < <(find scripts -type f -name "*.sh")
fi

# Check test scripts
if [[ -d "tests" ]]; then
    while IFS= read -r file; do
        ((total_files++)) || true
        check_file "$file" || true
    done < <(find tests -type f -name "*.sh")
fi

# Summary
echo
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                    ${BOLD}Validation Summary${NC}                      ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "  ${BOLD}Files checked:${NC} $total_files"
echo -e "  ${BOLD}Files with issues:${NC} $files_with_issues"
echo -e "  ${BOLD}Total issues found:${NC} $total_issues"

if [[ "$FIX_MODE" == "true" ]]; then
    echo -e "  ${BOLD}Issues fixed:${NC} $fixed_issues"
fi

echo

# Exit status
if [[ $total_issues -gt 0 ]]; then
    if [[ "$FIX_MODE" == "true" ]]; then
        if [[ $fixed_issues -gt 0 ]]; then
            echo -e "${GREEN}✓${NC} All issues have been fixed!"
            echo
            echo -e "${YELLOW}Recommendation:${NC} Review the changes and test the scripts"
            exit 0
        else
            echo -e "${RED}✗${NC} Issues found but could not be automatically fixed"
            exit 1
        fi
    else
        echo -e "${RED}✗${NC} Issues found! Run with ${BOLD}--fix${NC} to automatically correct them"
        echo -e "   Or manually add ${BOLD}-e${NC} flag to echo commands with color codes"
        
        if [[ "$CI_MODE" == "true" ]]; then
            exit 1
        else
            echo
            echo -e "${CYAN}Example fix:${NC}"
            echo -e "  ${RED}❌ echo \"  \\\${GREEN}Success\\\${NC}\"${NC}"
            echo -e "  ${GREEN}✓  echo -e \"  \\\${GREEN}Success\\\${NC}\"${NC}"
            exit 1
        fi
    fi
else
    echo -e "${GREEN}✓${NC} No issues found! All echo commands with color codes use -e flag"
    exit 0
fi
