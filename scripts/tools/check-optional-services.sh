#!/usr/bin/env bash
# Check for optional services that might not exist in minimal configurations
# This helps prevent "option does not exist" errors before building

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "Checking for potentially missing service dependencies..."
echo "======================================================="
echo

# Services that might not be available in minimal configurations
OPTIONAL_SERVICES=(
    "services.auditd"
    "security.audit"
    "security.apparmor"
    "services.fprintd"
    "services.acpid"
    "security.rtkit"
    "services.dbus"
    "services.pipewire"
)

# Check each service
ISSUES_FOUND=0

for service in "${OPTIONAL_SERVICES[@]}"; do
    echo -n "Checking for unconditional use of $service... "
    
    # Search for the service without proper conditionals
    if grep -r "$service\.enable\s*=\s*true" modules/ --include="*.nix" 2>/dev/null | grep -v "lib.mkIf" | grep -v "?" > /dev/null; then
        echo -e "${RED}FOUND${NC}"
        echo "  Files with potential issues:"
        grep -r "$service\.enable\s*=\s*true" modules/ --include="*.nix" 2>/dev/null | grep -v "lib.mkIf" | grep -v "?" | while read -r line; do
            echo "    - $line"
        done
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    else
        echo -e "${GREEN}OK${NC}"
    fi
done

echo
echo "======================================================="

# Check for proper wrapping pattern
echo
echo "Checking for proper conditional patterns..."
echo

# Look for files that use these services with proper conditionals
echo "Files using proper conditional checks:"
grep -r "config\.\(services\|security\)\s*?\s*[a-zA-Z0-9]*" modules/ --include="*.nix" 2>/dev/null | head -10

echo
echo "======================================================="

if [ $ISSUES_FOUND -eq 0 ]; then
    echo -e "${GREEN}✓ No issues found!${NC} All optional services appear to be properly wrapped."
else
    echo -e "${YELLOW}⚠ Found $ISSUES_FOUND potential issues.${NC}"
    echo
    echo "To fix these issues, wrap service configurations like this:"
    echo
    cat << 'EOF'
    # For services:
    (lib.mkIf (config.services ? serviceName) {
      services.serviceName = {
        enable = true;
        # ... other config
      };
    })
    
    # For security options:
    (lib.mkIf (config.security ? optionName) {
      security.optionName = {
        enable = true;
        # ... other config
      };
    })
EOF
fi

# Additional check for imports that might be missing
echo
echo "======================================================="
echo "Checking which configurations might need audit module import..."
echo

if grep -r "security\.\(sudoProtection\|credentialChain\)\.enable\s*=\s*true" . --include="*.nix" 2>/dev/null | grep -v "false" > /dev/null; then
    echo -e "${YELLOW}Note:${NC} Some configurations enable security modules that require audit."
    echo "Make sure to include this in your imports:"
    echo '    <nixpkgs/nixos/modules/security/audit.nix>'
fi