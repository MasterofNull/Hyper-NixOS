#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Analyze scripts for duplication that can be migrated to libraries
#

set -euo pipefail

SCRIPTS_DIR="${1:-scripts}"

echo "=== Script Duplication Analysis ==="
echo

# Count color definitions
echo "Color definitions:"
grep -r "^RED=\|^GREEN=\|^YELLOW=\|^BLUE=\|^NC=" "$SCRIPTS_DIR" --include="*.sh" 2>/dev/null | wc -l | xargs echo "  Total duplicates:"

# Count logging functions
echo
echo "Logging functions:"
grep -r "^log()\|^error()\|^warn()\|^info()" "$SCRIPTS_DIR" --include="*.sh" 2>/dev/null | wc -l | xargs echo "  Total duplicates:"

# Count root/permission checks
echo
echo "Permission checks:"
grep -r "check_root\|require_root\|EUID.*0" "$SCRIPTS_DIR" --include="*.sh" 2>/dev/null | wc -l | xargs echo "  Total instances:"

# Find scripts that don't source common.sh
echo
echo "Scripts not using common library:"
find "$SCRIPTS_DIR" -name "*.sh" -type f | while read -r script; do
    if ! grep -q "source.*common.sh\|\..*common.sh" "$script" 2>/dev/null; then
        echo "  - $script"
    fi
done

# Count scripts that could benefit from migration
echo
echo "Summary:"
total=$(find "$SCRIPTS_DIR" -name "*.sh" -type f | wc -l)
using_lib=$(grep -r "source.*common.sh" "$SCRIPTS_DIR" --include="*.sh" 2>/dev/null | wc -l)
not_using=$((total - using_lib))

echo "  Total scripts: $total"
echo "  Using libraries: $using_lib"
echo "  Need migration: $not_using"