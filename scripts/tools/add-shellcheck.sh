#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Add shellcheck directives to all shell scripts
#

set -euo pipefail

SCRIPTS_DIR="${1:-scripts}"
ADDED=0
SKIPPED=0

echo "Adding shellcheck directives to scripts..."

find "$SCRIPTS_DIR" -name "*.sh" -type f | while read -r script; do
    # Skip if already has shellcheck directive
    if grep -q "^# shellcheck" "$script"; then
        ((SKIPPED++)) || true
        continue
    fi
    
    # Add shellcheck directive after shebang
    # Common directives to disable:
    # SC2034 - Unused variables (often used in sourced scripts)
    # SC2154 - Variable referenced but not assigned (sourced from other scripts)
    # SC1091 - Not following sourced files
    
    # Create temp file
    tmpfile=$(mktemp)
    
    # Get first line (shebang)
    head -1 "$script" > "$tmpfile"
    
    # Add shellcheck directive
    echo "# shellcheck disable=SC2034,SC2154,SC1091" >> "$tmpfile"
    
    # Add rest of file
    tail -n +2 "$script" >> "$tmpfile"
    
    # Replace original
    mv "$tmpfile" "$script"
    
    echo "  ✓ $script"
    ((ADDED++)) || true
done

echo
echo "Summary:"
echo "  Added shellcheck to: $ADDED scripts"
echo "  Already had shellcheck: $SKIPPED scripts"

# Create .shellcheckrc for project-wide settings
cat > .shellcheckrc << 'EOF'
# Hyper-NixOS ShellCheck Configuration

# Enable all optional checks
enable=all

# Exclude certain checks project-wide
disable=SC2034  # Unused variables (used in sourced scripts)
disable=SC2154  # Referenced but not assigned (from sourced scripts)
disable=SC1091  # Not following sourced files

# Set shell
shell=bash

# External sources
external-sources=true
EOF

echo
echo "Created .shellcheckrc for project-wide settings"
echo
echo "Next steps:"
echo "1. Run: shellcheck scripts/**/*.sh"
echo "2. Fix any remaining issues"
echo "3. Add shellcheck to CI/CD pipeline"