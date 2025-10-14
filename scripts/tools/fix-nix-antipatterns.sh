#!/usr/bin/env bash
#
# Fix common NixOS anti-patterns in Hyper-NixOS modules
#

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Configuration
DRY_RUN=false
BACKUP=true
MODULES_DIR="${1:-modules}"

# Usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [DIRECTORY]

Fix common NixOS anti-patterns in modules.

Options:
    -n, --dry-run     Show what would be done without making changes
    -b, --no-backup   Don't create backups
    -h, --help        Show this help message

Arguments:
    DIRECTORY         Directory to scan for .nix files (default: modules)

Fixes:
    - Replaces 'with lib;' with explicit imports
    - Replaces 'with pkgs;' with explicit package lists
    - Fixes common namespace issues

Example:
    $0 modules/
    $0 --dry-run .

EOF
}

# Parse arguments
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
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
        *)
            MODULES_DIR="$1"
            shift
            ;;
    esac
done

# Check if directory exists
if [[ ! -d "$MODULES_DIR" ]]; then
    echo -e "${RED}Directory not found: $MODULES_DIR${NC}"
    exit 1
fi

# Fix 'with lib;' anti-pattern
fix_with_lib() {
    local file="$1"
    local temp_file="${file}.tmp"
    local changed=false
    
    # Check if file uses 'with lib;'
    if ! grep -q "^with lib;" "$file"; then
        return 1
    fi
    
    echo -e "${YELLOW}Processing: $file${NC}"
    
    # Extract which lib functions are actually used
    local lib_functions=$(grep -oE '\b(mk[A-Z][a-zA-Z]+|types\.[a-zA-Z]+|lib\.[a-zA-Z]+)' "$file" | \
        sed 's/^lib\.//' | \
        grep -E '^(mk|types)' | \
        sort -u || true)
    
    # Common lib functions
    local common_imports="mkOption mkEnableOption mkIf mkDefault mkForce mkMerge types"
    
    # Combine and deduplicate
    local all_imports=$(echo "$common_imports $lib_functions" | tr ' ' '\n' | sort -u | tr '\n' ' ')
    
    # Create the inherit line
    local inherit_line="  inherit (lib) ${all_imports};"
    
    # Replace 'with lib;' with inherit
    awk -v inherit="$inherit_line" '
        /^with lib;/ {
            print "let"
            print inherit
            print "in"
            next
        }
        { print }
    ' "$file" > "$temp_file"
    
    # Check if changes were made
    if ! diff -q "$file" "$temp_file" >/dev/null; then
        changed=true
        
        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "${GREEN}Would fix 'with lib;' pattern${NC}"
            diff -u "$file" "$temp_file" || true
            rm -f "$temp_file"
        else
            if [[ "$BACKUP" == "true" ]]; then
                cp "$file" "${file}.bak"
            fi
            mv "$temp_file" "$file"
            echo -e "${GREEN}Fixed 'with lib;' pattern${NC}"
        fi
    else
        rm -f "$temp_file"
    fi
    
    return $([ "$changed" == "true" ] && echo 0 || echo 1)
}

# Fix 'with pkgs;' anti-pattern
fix_with_pkgs() {
    local file="$1"
    local temp_file="${file}.tmp"
    local changed=false
    
    # Look for 'environment.systemPackages = with pkgs;'
    if ! grep -q "with pkgs;" "$file"; then
        return 1
    fi
    
    echo -e "${YELLOW}Processing: $file${NC}"
    
    # Extract package names after 'with pkgs;'
    local in_packages=false
    local packages=""
    
    while IFS= read -r line; do
        if [[ "$line" =~ "with pkgs;" ]]; then
            in_packages=true
        elif [[ "$in_packages" == true ]] && [[ "$line" =~ \]; ]]; then
            in_packages=false
        elif [[ "$in_packages" == true ]] && [[ "$line" =~ ^[[:space:]]+([a-zA-Z0-9_-]+) ]]; then
            packages+="${BASH_REMATCH[1]} "
        fi
    done < "$file"
    
    # If we found packages, create explicit references
    if [[ -n "$packages" ]]; then
        # Replace 'with pkgs;' blocks
        awk '
            /with pkgs;/ {
                print "# Explicit package references (replaced '\''with pkgs;'\'')"
                getline
                print $0
                in_block = 1
                next
            }
            in_block && /^[[:space:]]+[a-zA-Z0-9_-]+/ {
                gsub(/^[[:space:]]+/, "    pkgs.", $0)
                print $0
                next
            }
            in_block && /\];/ {
                in_block = 0
                print $0
                next
            }
            { print }
        ' "$file" > "$temp_file"
        
        changed=true
    fi
    
    if [[ "$changed" == "true" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "${GREEN}Would fix 'with pkgs;' pattern${NC}"
            diff -u "$file" "$temp_file" || true
            rm -f "$temp_file"
        else
            if [[ "$BACKUP" == "true" ]]; then
                cp "$file" "${file}.bak"
            fi
            mv "$temp_file" "$file"
            echo -e "${GREEN}Fixed 'with pkgs;' pattern${NC}"
        fi
    else
        rm -f "$temp_file"
    fi
    
    return $([ "$changed" == "true" ] && echo 0 || echo 1)
}

# Main processing
main() {
    echo -e "${GREEN}NixOS Anti-pattern Fixer${NC}"
    echo -e "Scanning directory: ${MODULES_DIR}\n"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}Running in DRY-RUN mode${NC}\n"
    fi
    
    local total_files=0
    local fixed_files=0
    
    # Find all .nix files
    while IFS= read -r -d '' file; do
        ((total_files++))
        
        # Skip flake.nix and other special files
        if [[ "$(basename "$file")" == "flake.nix" ]]; then
            continue
        fi
        
        # Fix anti-patterns
        local fixed=false
        
        if fix_with_lib "$file"; then
            fixed=true
        fi
        
        if fix_with_pkgs "$file"; then
            fixed=true
        fi
        
        if [[ "$fixed" == "true" ]]; then
            ((fixed_files++))
        fi
        
    done < <(find "$MODULES_DIR" -name "*.nix" -type f -print0)
    
    # Summary
    echo -e "\n${GREEN}Summary:${NC}"
    echo "  Total files scanned: $total_files"
    echo "  Files fixed: $fixed_files"
    
    if [[ "$BACKUP" == "true" ]] && [[ "$fixed_files" -gt 0 ]]; then
        echo -e "\n${YELLOW}Backups created with .bak extension${NC}"
    fi
    
    if [[ "$DRY_RUN" == "false" ]] && [[ "$fixed_files" -gt 0 ]]; then
        echo -e "\n${GREEN}Fixes applied successfully!${NC}"
        echo "Please test your configuration with: nixos-rebuild dry-build"
    fi
}

# Run main
main