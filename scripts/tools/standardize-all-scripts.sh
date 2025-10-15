#!/usr/bin/env bash
# Standardize all scripts to use common libraries

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "====================================================="
echo "  Script Standardization Tool"
echo "====================================================="
echo

# Define scripts that should use common library
SCRIPTS_TO_FIX=(
    # High priority - frequently used
    "scripts/create_vm_wizard.sh"
    "scripts/guided_system_test.sh"
    "scripts/preflight_check.sh"
    "scripts/security_audit.sh"
    "scripts/update_hypervisor.sh"
    "scripts/hardware_detect.sh"
    "scripts/iso_manager.sh"
    "scripts/network_manager.sh"
    "scripts/storage_manager.sh"
    "scripts/vm_dashboard.sh"
    
    # Medium priority - system tools
    "scripts/backup_manager.sh"
    "scripts/health_check.sh"
    "scripts/resource_monitor.sh"
    "scripts/zone_manager.sh"
    "scripts/vfio_workflow.sh"
    "scripts/per_vm_firewall.sh"
    "scripts/foundational_networking_setup.sh"
    "scripts/toggle_boot_features.sh"
    "scripts/harden_permissions.sh"
    "scripts/relax_permissions.sh"
)

FIXED=0
SKIPPED=0
ERRORS=0

for script_path in "${SCRIPTS_TO_FIX[@]}"; do
    full_path="$WORKSPACE_ROOT/$script_path"
    
    if [[ ! -f "$full_path" ]]; then
        echo "⚠️  Skip: $script_path (not found)"
        ((SKIPPED++))
        continue
    fi
    
    # Check if already using common library
    if grep -q "source.*lib/common.sh" "$full_path"; then
        echo "✓ Skip: $script_path (already standardized)"
        ((SKIPPED++))
        continue
    fi
    
    echo "📝 Processing: $script_path"
    
    # Create backup
    cp "$full_path" "$full_path.backup-$(date +%s)"
    
    # Add common library source after shebang
    # Find the first non-comment, non-empty line after shebang
    awk '
    BEGIN { found_shebang=0; inserted=0; }
    /^#!/ { print; found_shebang=1; next; }
    found_shebang && !inserted && /^[^#]/ && NF > 0 {
        print "# Source common library for standardized functions";
        print "SCRIPT_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"";
        print "source \"${SCRIPT_DIR}/lib/common.sh\" 2>/dev/null || true";
        print "";
        inserted=1;
    }
    { print }
    ' "$full_path" > "$full_path.tmp" && mv "$full_path.tmp" "$full_path"
    
    # Make executable
    chmod +x "$full_path"
    
    ((FIXED++))
    echo "  ✓ Added common library source"
done

echo
echo "====================================================="
echo "Summary:"
echo "  Fixed: $FIXED"
echo "  Skipped: $SKIPPED"
echo "  Errors: $ERRORS"
echo "====================================================="
echo
echo "Next steps:"
echo "1. Review modified scripts"
echo "2. Replace duplicated functions with library calls"
echo "3. Test scripts individually"
echo "4. Commit changes"
