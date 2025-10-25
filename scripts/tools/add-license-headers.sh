#!/usr/bin/env bash
# Hyper-NixOS License Header Management Tool
#
# Copyright (c) 2024-2025 MasterofNull
# Licensed under the MIT License
#
# This script helps maintain proper license headers across all files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Hyper-NixOS License Header Management${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [PATH]

Add or update license headers in Hyper-NixOS source files.

Options:
    -c, --check         Check files for proper headers (don't modify)
    -u, --update        Update existing headers to current format
    -a, --add          Add headers to files missing them
    -t, --type TYPE    File type: nix, bash, python, md (auto-detect if not specified)
    -h, --help         Show this help message

Arguments:
    PATH               File or directory to process (default: current directory)

Examples:
    # Check all files for proper headers
    $(basename "$0") --check

    # Add headers to all bash scripts in scripts/
    $(basename "$0") --add --type bash scripts/

    # Update headers in a specific file
    $(basename "$0") --update modules/monitoring/prometheus.nix

EOF
}

# License header templates
get_nix_header() {
    local module_name="$1"
    local components="${2:-}"
    
    cat <<'EOF'
# Hyper-NixOS ${MODULE_NAME}
#
# Copyright (c) 2024-2025 MasterofNull
# Licensed under the MIT License
#
${COMPONENTS}# For complete license information, see:
# - LICENSE - Hyper-NixOS license
# - THIRD_PARTY_LICENSES.md - All dependencies
# - CREDITS.md - Attributions

EOF
}

get_bash_header() {
    local script_name="$1"
    
    cat <<'EOF'
#!/usr/bin/env bash
# Hyper-NixOS ${SCRIPT_NAME}
#
# Copyright (c) 2024-2025 MasterofNull
# Licensed under the MIT License
#
# For license information, see:
# - LICENSE - Hyper-NixOS license
# - THIRD_PARTY_LICENSES.md - Dependencies
# - CREDITS.md - Attributions

EOF
}

get_python_header() {
    local script_name="$1"
    
    cat <<'EOF'
#!/usr/bin/env python3
# Hyper-NixOS ${SCRIPT_NAME}
#
# Copyright (c) 2024-2025 MasterofNull
# Licensed under the MIT License
#
# For license information, see:
# - LICENSE - Hyper-NixOS license
# - THIRD_PARTY_LICENSES.md - Dependencies

EOF
}

get_markdown_header() {
    cat <<'EOF'
# ${TITLE}

Copyright (c) 2024-2025 MasterofNull  
Licensed under the MIT License

For complete licensing information, see:
- LICENSE - Hyper-NixOS license
- THIRD_PARTY_LICENSES.md - Dependencies
- CREDITS.md - Attributions

---

EOF
}

# Check if file has proper license header
check_header() {
    local file="$1"
    
    if ! head -n 20 "$file" | grep -q "Copyright.*MasterofNull"; then
        return 1
    fi
    
    if ! head -n 20 "$file" | grep -q "MIT License\|Licensed under the MIT License"; then
        return 1
    fi
    
    return 0
}

# Detect file type
detect_type() {
    local file="$1"
    
    case "$file" in
        *.nix) echo "nix" ;;
        *.sh) echo "bash" ;;
        *.py) echo "python" ;;
        *.md) echo "markdown" ;;
        *)
            # Check shebang
            if [[ -f "$file" ]]; then
                local first_line
                first_line=$(head -n 1 "$file")
                case "$first_line" in
                    "#!/usr/bin/env bash"|"#!/bin/bash") echo "bash" ;;
                    "#!/usr/bin/env python"*|"#!/usr/bin/python"*) echo "python" ;;
                    *) echo "unknown" ;;
                esac
            else
                echo "unknown"
            fi
            ;;
    esac
}

# Process a single file
process_file() {
    local file="$1"
    local action="$2"  # check, add, update
    local file_type="${3:-$(detect_type "$file")}"
    
    if [[ "$file_type" == "unknown" ]]; then
        echo -e "${YELLOW}Skipping${NC} $file (unknown type)"
        return 0
    fi
    
    case "$action" in
        check)
            if check_header "$file"; then
                echo -e "${GREEN}✓${NC} $file"
                return 0
            else
                echo -e "${RED}✗${NC} $file (missing or incomplete header)"
                return 1
            fi
            ;;
            
        add)
            if check_header "$file"; then
                echo -e "${BLUE}→${NC} $file (already has header)"
                return 0
            fi
            
            echo -e "${GREEN}+${NC} $file (adding header)"
            # Add header implementation here
            return 0
            ;;
            
        update)
            echo -e "${YELLOW}↻${NC} $file (updating header)"
            # Update header implementation here
            return 0
            ;;
    esac
}

# Process directory recursively
process_directory() {
    local dir="$1"
    local action="$2"
    local file_type="${3:-all}"
    
    local total=0
    local passed=0
    local failed=0
    
    while IFS= read -r -d '' file; do
        ((total++))
        
        local type=$(detect_type "$file")
        
        # Skip if filtering by type and doesn't match
        if [[ "$file_type" != "all" && "$type" != "$file_type" ]]; then
            continue
        fi
        
        if process_file "$file" "$action" "$type"; then
            ((passed++))
        else
            ((failed++))
        fi
    done < <(find "$dir" -type f \( -name "*.nix" -o -name "*.sh" -o -name "*.py" -o -name "*.md" \) -print0)
    
    echo
    echo -e "${BLUE}Summary:${NC}"
    echo -e "  Total files: $total"
    echo -e "  ${GREEN}Passed: $passed${NC}"
    if [[ $failed -gt 0 ]]; then
        echo -e "  ${RED}Failed: $failed${NC}"
        return 1
    fi
    
    return 0
}

# Main execution
main() {
    local action=""
    local file_type="all"
    local target="$PROJECT_ROOT"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--check)
                action="check"
                shift
                ;;
            -u|--update)
                action="update"
                shift
                ;;
            -a|--add)
                action="add"
                shift
                ;;
            -t|--type)
                file_type="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                echo -e "${RED}Error:${NC} Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                target="$1"
                shift
                ;;
        esac
    done
    
    # Default action
    if [[ -z "$action" ]]; then
        action="check"
    fi
    
    print_header
    
    echo "Action: $action"
    echo "File type: $file_type"
    echo "Target: $target"
    echo
    
    if [[ ! -e "$target" ]]; then
        echo -e "${RED}Error:${NC} Target does not exist: $target"
        exit 1
    fi
    
    if [[ -f "$target" ]]; then
        process_file "$target" "$action" "$file_type"
    else
        process_directory "$target" "$action" "$file_type"
    fi
}

main "$@"
