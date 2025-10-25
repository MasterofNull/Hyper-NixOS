#!/usr/bin/env bash
# Audit NixOS module structure for best practices compliance

set -euo pipefail

echo "====================================================="
echo "  NixOS Module Structure Audit"
echo "====================================================="
echo

TOTAL=0
WITH_MKIF=0
WITH_OPTIONS=0
WITH_ENABLE=0
NO_ISSUES=0

echo "Checking all modules..."
echo

while IFS= read -r -d '' file; do
    ((TOTAL++))
    basename=$(basename "$file")
    
    # Check for lib.mkIf usage
    if grep -q "lib.mkIf" "$file"; then
        ((WITH_MKIF++))
    fi
    
    # Check for options definition
    if grep -q "^  options\." "$file" || grep -q "^  options =" "$file"; then
        ((WITH_OPTIONS++))
    fi
    
    # Check for enable option
    if grep -q "\.enable.*mkEnableOption\|\.enable.*mkOption" "$file"; then
        ((WITH_ENABLE++))
    fi
    
    # Check for both good patterns
    if grep -q "lib.mkIf" "$file" && grep -q "options\." "$file"; then
        ((NO_ISSUES++))
    fi
    
done < <(find /workspace/modules -name "*.nix" -type f -print0)

echo "====================================================="
echo "Results:"
echo "====================================================="
echo "Total modules: $TOTAL"
echo "Using lib.mkIf: $WITH_MKIF ($(( WITH_MKIF * 100 / TOTAL ))%)"
echo "Define options: $WITH_OPTIONS ($(( WITH_OPTIONS * 100 / TOTAL ))%)"
echo "Have enable option: $WITH_ENABLE ($(( WITH_ENABLE * 100 / TOTAL ))%)"
echo "Follow best practices: $NO_ISSUES ($(( NO_ISSUES * 100 / TOTAL ))%)"
echo

NEEDS_MKIF=$((TOTAL - WITH_MKIF))
NEEDS_OPTIONS=$((TOTAL - WITH_OPTIONS))

echo "====================================================="
echo "Action Items:"
echo "====================================================="
echo "Modules needing lib.mkIf: $NEEDS_MKIF"
echo "Modules needing options: $NEEDS_OPTIONS"
echo
echo "Run 'fix-module-structure.sh' to add missing patterns"
echo "====================================================="
