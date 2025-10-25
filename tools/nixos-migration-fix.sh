#!/usr/bin/env bash
# NixOS Migration Fix Tool
# Automatically applies fixes for deprecated NixOS patterns
#
# Usage:
#   ./tools/nixos-migration-fix.sh [--auto|--interactive|--dry-run]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${MODE:-interactive}"
BACKUP="${BACKUP:-true}"
BACKUP_DIR="backups/migration-$(date +%Y%m%d-%H%M%S)"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Counters
FIXED=0
SKIPPED=0
FAILED=0

print_header() {
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}  NixOS Migration Fix Tool${NC}"
    echo -e "${BOLD}${BLUE}  Mode: ${MODE}${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo
}

# Backup file before modification
backup_file() {
    local file="$1"
    
    if [[ "$BACKUP" == "true" ]]; then
        local backup_path="${BACKUP_DIR}/${file}"
        mkdir -p "$(dirname "$backup_path")"
        cp "$file" "$backup_path"
        echo -e "${CYAN}  Backed up:${NC} $file → $backup_path"
    fi
}

# Apply fix to file
apply_fix() {
    local file="$1"
    local search="$2"
    local replace="$3"
    local description="$4"
    
    # Check if pattern exists
    if ! grep -q "$search" "$file"; then
        return 1
    fi
    
    echo
    echo -e "${BOLD}File:${NC} $file"
    echo -e "${BOLD}Fix:${NC} $description"
    echo -e "${BOLD}Change:${NC} ${RED}$search${NC} → ${GREEN}$replace${NC}"
    
    # Show context
    echo -e "\n${CYAN}Context:${NC}"
    grep -n -C 2 "$search" "$file" | head -15 || true
    echo
    
    local do_fix=false
    
    case "$MODE" in
        auto)
            do_fix=true
            echo -e "${GREEN}[AUTO] Applying fix...${NC}"
            ;;
        interactive)
            read -p "Apply this fix? [y/N] " -r
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                do_fix=true
            else
                echo -e "${YELLOW}[SKIP] Skipped by user${NC}"
                ((SKIPPED++))
            fi
            ;;
        dry-run)
            echo -e "${CYAN}[DRY-RUN] Would apply fix${NC}"
            ((FIXED++))
            return 0
            ;;
    esac
    
    if [[ "$do_fix" == "true" ]]; then
        backup_file "$file"
        
        if sed -i "s|$search|$replace|g" "$file"; then
            echo -e "${GREEN}✓ Fix applied${NC}"
            ((FIXED++))
        else
            echo -e "${RED}✗ Fix failed${NC}"
            ((FAILED++))
            return 1
        fi
    fi
}

# Fix services.auditd → security.auditd
fix_auditd_namespace() {
    echo -e "\n${BOLD}${BLUE}Fixing auditd namespace changes...${NC}\n"
    
    local files=$(find modules -name "*.nix" -type f -exec grep -l "services\.auditd" {} \; 2>/dev/null || true)
    
    if [[ -z "$files" ]]; then
        echo -e "${GREEN}✓ No auditd namespace issues found${NC}"
        return 0
    fi
    
    for file in $files; do
        apply_fix "$file" \
            "services\.auditd" \
            "security.auditd" \
            "Update auditd namespace (services → security)"
        
        # Also fix conditional checks
        if grep -q "services ? auditd" "$file"; then
            apply_fix "$file" \
                "services ? auditd" \
                "security ? auditd" \
                "Update auditd conditional check"
        fi
        
        if grep -q "config\.services\.auditd" "$file"; then
            apply_fix "$file" \
                "config\.services\.auditd" \
                "config.security.auditd" \
                "Update auditd config reference"
        fi
    done
}

# Fix pythonPackages → python3Packages
fix_python_packages() {
    echo -e "\n${BOLD}${BLUE}Fixing Python package references...${NC}\n"
    
    local files=$(find modules -name "*.nix" -type f -exec grep -l "\bpythonPackages\b" {} \; 2>/dev/null || true)
    
    if [[ -z "$files" ]]; then
        echo -e "${GREEN}✓ No Python package issues found${NC}"
        return 0
    fi
    
    for file in $files; do
        apply_fix "$file" \
            "\bpythonPackages\b" \
            "python3Packages" \
            "Update Python package references"
    done
}

# Add lib.mkDefault where appropriate
fix_mkdefault_missing() {
    echo -e "\n${BOLD}${BLUE}Adding lib.mkDefault for overridability...${NC}\n"
    
    # Find patterns like: enable = true; without mkDefault
    local files=$(find modules -name "*.nix" -type f -exec grep -l "\.enable = true;" {} \; 2>/dev/null || true)
    
    if [[ -z "$files" ]]; then
        echo -e "${GREEN}✓ No mkDefault issues found${NC}"
        return 0
    fi
    
    for file in $files; do
        # Only suggest, don't auto-fix (requires AST analysis)
        if grep -q "\.enable = true;" "$file" && ! grep -q "lib\.mkDefault true" "$file"; then
            echo -e "\n${YELLOW}[INFO]${NC} $file"
            echo "  Consider using lib.mkDefault for enable options:"
            echo "  enable = true;  →  enable = lib.mkDefault true;"
            echo
        fi
    done
}

# Generate summary report
generate_report() {
    local report_file="MIGRATION_REPORT_$(date +%Y-%m-%d).md"
    
    cat > "$report_file" <<EOF
# NixOS Migration Report
Generated: $(date)

## Summary
- **Fixed:** ${FIXED} issues
- **Skipped:** ${SKIPPED} issues
- **Failed:** ${FAILED} issues

## Changes Applied

### Auditd Namespace Migration
Changed \`services.auditd\` to \`security.auditd\` across:
$(find "$BACKUP_DIR" -type f -name "*.nix" 2>/dev/null | wc -l) files

### Backups
All modified files backed up to: \`${BACKUP_DIR}/\`

## Next Steps

1. **Validate Changes:**
   \`\`\`bash
   nixos-rebuild build
   \`\`\`

2. **Review Diffs:**
   \`\`\`bash
   diff -r backups/migration-*/ modules/
   \`\`\`

3. **Test System:**
   \`\`\`bash
   nixos-rebuild test
   \`\`\`

4. **Apply Permanently:**
   \`\`\`bash
   sudo nixos-rebuild switch
   \`\`\`

## Rollback

If issues occur, restore from backup:
\`\`\`bash
cp -r ${BACKUP_DIR}/* ./
\`\`\`

EOF
    
    echo -e "\n${GREEN}Report generated: $report_file${NC}"
}

# Main execution
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --auto)
                MODE="auto"
                shift
                ;;
            --interactive)
                MODE="interactive"
                shift
                ;;
            --dry-run)
                MODE="dry-run"
                shift
                ;;
            --no-backup)
                BACKUP="false"
                shift
                ;;
            --help|-h)
                cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --auto              Apply all fixes automatically
  --interactive       Review each fix (default)
  --dry-run          Show what would be fixed
  --no-backup        Don't create backups
  --help, -h         Show this help

Examples:
  $0                           # Interactive mode
  $0 --auto --no-backup        # Auto-fix without backups
  $0 --dry-run                 # Preview changes

Environment Variables:
  MODE      Override mode (auto|interactive|dry-run)
  BACKUP    Create backups (true|false)
EOF
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                exit 1
                ;;
        esac
    done
    
    print_header
    
    # Create backup directory
    if [[ "$BACKUP" == "true" ]] && [[ "$MODE" != "dry-run" ]]; then
        mkdir -p "$BACKUP_DIR"
        echo -e "${CYAN}Backup directory: $BACKUP_DIR${NC}\n"
    fi
    
    # Run fixes
    fix_auditd_namespace
    fix_python_packages
    fix_mkdefault_missing
    
    # Summary
    echo
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}Summary:${NC}"
    echo -e "  ${GREEN}Fixed:${NC}   ${FIXED}"
    echo -e "  ${YELLOW}Skipped:${NC} ${SKIPPED}"
    echo -e "  ${RED}Failed:${NC}  ${FAILED}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}"
    
    if [[ "$MODE" != "dry-run" ]] && [[ $FIXED -gt 0 ]]; then
        generate_report
        
        echo
        echo -e "${YELLOW}⚠️  Important: Test your changes!${NC}"
        echo "Run: nixos-rebuild build"
        echo
    fi
    
    exit 0
}

main "$@"
