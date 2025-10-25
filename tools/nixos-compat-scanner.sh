#!/usr/bin/env bash
# NixOS Compatibility Scanner
# Scans codebase for deprecated NixOS patterns and compatibility issues
#
# Usage:
#   ./tools/nixos-compat-scanner.sh [--target-version VERSION] [--format json|text]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATION_RULES_DIR="${SCRIPT_DIR}/migration-rules"
TARGET_VERSION="${TARGET_VERSION:-24.05}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-text}"
VERBOSE="${VERBOSE:-false}"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Counters
ERRORS=0
WARNINGS=0
INFO=0

# Results array
declare -a RESULTS=()

# Print functions
print_header() {
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}  NixOS Compatibility Scanner${NC}"
    echo -e "${BOLD}${BLUE}  Target: NixOS ${TARGET_VERSION}${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo
}

print_result() {
    local severity="$1"
    local file="$2"
    local line="$3"
    local description="$4"
    local suggestion="$5"
    
    case "$severity" in
        ERROR)
            echo -e "${RED}[ERROR]${NC} ${file}:${line}"
            ((ERRORS++))
            ;;
        WARNING)
            echo -e "${YELLOW}[WARNING]${NC} ${file}:${line}"
            ((WARNINGS++))
            ;;
        INFO)
            echo -e "${CYAN}[INFO]${NC} ${file}:${line}"
            ((INFO++))
            ;;
    esac
    
    echo "  Issue: $description"
    [[ -n "$suggestion" ]] && echo "  Fix: $suggestion"
    echo
    
    # Store for JSON output
    RESULTS+=("{\"severity\":\"$severity\",\"file\":\"$file\",\"line\":$line,\"description\":\"$description\",\"suggestion\":\"$suggestion\"}")
}

# Check for required tools
check_requirements() {
    local missing=()
    
    for cmd in grep find; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Error: Missing required tools: ${missing[*]}" >&2
        exit 1
    fi
}

# Load migration rules
load_rules() {
    local rules_file="${MIGRATION_RULES_DIR}/nixos-${TARGET_VERSION}.toml"
    
    if [[ ! -f "$rules_file" ]]; then
        echo "Warning: No migration rules found for NixOS ${TARGET_VERSION}" >&2
        echo "File not found: $rules_file" >&2
        return 1
    fi
    
    [[ "$VERBOSE" == "true" ]] && echo "Loading rules from: $rules_file"
}

# Scan for services.auditd pattern
scan_auditd_namespace() {
    local pattern='services\.auditd'
    
    [[ "$VERBOSE" == "true" ]] && echo "Scanning for: $pattern"
    
    find modules -name "*.nix" -type f | while IFS= read -r file; do
        local line_num=0
        while IFS= read -r line; do
            ((line_num++))
            if echo "$line" | grep -qE "$pattern"; then
                print_result "ERROR" "$file" "$line_num" \
                    "Deprecated pattern: services.auditd (moved to security.auditd in NixOS 24.05)" \
                    "Replace 'services.auditd' with 'security.auditd'"
            fi
        done < "$file"
    done
}

# Scan for networking.useDHCP deprecation
scan_networking_useDHCP() {
    local pattern='networking\.useDHCP\s*='
    
    [[ "$VERBOSE" == "true" ]] && echo "Scanning for: networking.useDHCP"
    
    find modules configuration.nix -name "*.nix" -type f 2>/dev/null | while IFS= read -r file; do
        local line_num=0
        while IFS= read -r line; do
            ((line_num++))
            if echo "$line" | grep -qE "$pattern"; then
                print_result "WARNING" "$file" "$line_num" \
                    "Deprecated option: networking.useDHCP (use per-interface configuration)" \
                    "Replace with per-interface useDHCP settings"
            fi
        done < "$file"
    done
}

# Scan for pythonPackages usage
scan_python_packages() {
    local pattern='\bpythonPackages\b'
    
    [[ "$VERBOSE" == "true" ]] && echo "Scanning for: pythonPackages"
    
    find modules -name "*.nix" -type f | while IFS= read -r file; do
        local line_num=0
        while IFS= read -r line; do
            ((line_num++))
            if echo "$line" | grep -qE "$pattern"; then
                print_result "ERROR" "$file" "$line_num" \
                    "Removed package set: pythonPackages (use python3Packages)" \
                    "Replace 'pythonPackages' with 'python3Packages'"
            fi
        done < "$file"
    done
}

# Scan for lib.mkIf usage without parentheses (common anti-pattern)
scan_mkif_antipattern() {
    local pattern='lib\.mkIf\s+[^(]'
    
    [[ "$VERBOSE" == "true" ]] && echo "Scanning for: lib.mkIf anti-pattern"
    
    find modules -name "*.nix" -type f | while IFS= read -r file; do
        local line_num=0
        while IFS= read -r line; do
            ((line_num++))
            if echo "$line" | grep -qE "$pattern" && ! echo "$line" | grep -q "lib.mkIf.*{"; then
                # Only warn if it looks suspicious
                if echo "$line" | grep -qE 'lib\.mkIf\s+config\.[a-zA-Z]'; then
                    print_result "INFO" "$file" "$line_num" \
                        "Potential issue: lib.mkIf condition without parentheses" \
                        "Consider using: lib.mkIf (condition) { ... }"
                fi
            fi
        done < "$file"
    done
}

# Check for missing conditional checks
scan_missing_conditionals() {
    local pattern='(services|security)\.[a-zA-Z]+\.enable\s*='
    
    [[ "$VERBOSE" == "true" ]] && echo "Scanning for: missing conditional checks"
    
    find modules -name "*.nix" -type f | while IFS= read -r file; do
        # Check if file has lib.mkIf or config = lib.mkMerge
        if ! grep -q 'lib\.mkIf\|lib\.mkMerge' "$file"; then
            # Check if it sets service options directly
            if grep -qE "$pattern" "$file"; then
                local first_match=$(grep -n -m 1 -E "$pattern" "$file" | cut -d: -f1)
                print_result "INFO" "$file" "${first_match:-0}" \
                    "Service configuration without conditional check" \
                    "Consider wrapping in lib.mkIf to allow conditional enabling"
            fi
        fi
    done
}

# Output results
output_results() {
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo "{"
        echo "  \"target_version\": \"${TARGET_VERSION}\","
        echo "  \"scan_date\": \"$(date -Iseconds)\","
        echo "  \"summary\": {"
        echo "    \"errors\": ${ERRORS},"
        echo "    \"warnings\": ${WARNINGS},"
        echo "    \"info\": ${INFO}"
        echo "  },"
        echo "  \"issues\": ["
        
        local first=true
        for result in "${RESULTS[@]}"; do
            if [[ "$first" == "true" ]]; then
                first=false
            else
                echo ","
            fi
            echo "    $result"
        done
        
        echo
        echo "  ]"
        echo "}"
    else
        # Text output (already printed during scan)
        echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD}Summary:${NC}"
        echo -e "  ${RED}Errors:${NC}   ${ERRORS}"
        echo -e "  ${YELLOW}Warnings:${NC} ${WARNINGS}"
        echo -e "  ${CYAN}Info:${NC}     ${INFO}"
        echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}"
        
        if [[ $ERRORS -gt 0 ]]; then
            echo
            echo -e "${RED}⚠️  Build may fail with NixOS ${TARGET_VERSION}${NC}"
            echo "Run migration tool: ./tools/nixos-migration-fix.sh"
        elif [[ $WARNINGS -gt 0 ]]; then
            echo
            echo -e "${YELLOW}⚠️  Some features may not work optimally${NC}"
            echo "Review warnings and consider updating deprecated options"
        else
            echo
            echo -e "${GREEN}✓ No compatibility issues detected${NC}"
        fi
    fi
}

# Main execution
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --target-version)
                TARGET_VERSION="$2"
                shift 2
                ;;
            --format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            --verbose|-v)
                VERBOSE="true"
                shift
                ;;
            --help|-h)
                cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --target-version VERSION   Target NixOS version (default: 24.05)
  --format FORMAT            Output format: text|json (default: text)
  --verbose, -v              Verbose output
  --help, -h                 Show this help

Examples:
  $0                                    # Scan for NixOS 24.05 compatibility
  $0 --target-version 24.11             # Scan for NixOS 24.11
  $0 --format json > report.json        # JSON output
  
Environment Variables:
  TARGET_VERSION   Override target version
  OUTPUT_FORMAT    Override output format
  VERBOSE          Enable verbose mode
EOF
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                echo "Use --help for usage information" >&2
                exit 1
                ;;
        esac
    done
    
    check_requirements
    
    if [[ "$OUTPUT_FORMAT" == "text" ]]; then
        print_header
    fi
    
    # Load rules (optional, we have hardcoded patterns for now)
    load_rules || true
    
    # Run scans
    [[ "$VERBOSE" == "true" ]] && echo "Starting compatibility scan..."
    
    scan_auditd_namespace
    scan_networking_useDHCP
    scan_python_packages
    scan_mkif_antipattern
    scan_missing_conditionals
    
    # Output results
    output_results
    
    # Exit code based on errors
    if [[ $ERRORS -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

main "$@"
