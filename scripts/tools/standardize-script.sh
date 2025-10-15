#!/usr/bin/env bash
# Script Standardization Tool
# Automatically standardizes a script to use common libraries

set -euo pipefail

SCRIPT_TO_STANDARDIZE="${1:-}"

if [ -z "${SCRIPT_TO_STANDARDIZE}" ]; then
    echo "Usage: $0 <script-path>"
    echo ""
    echo "This tool will:"
    echo "  1. Add standard header"
    echo "  2. Source common libraries"
    echo "  3. Standardize error handling"
    echo "  4. Add logging"
    exit 1
fi

if [ ! -f "${SCRIPT_TO_STANDARDIZE}" ]; then
    echo "Error: File not found: ${SCRIPT_TO_STANDARDIZE}"
    exit 1
fi

# Create backup
BACKUP="${SCRIPT_TO_STANDARDIZE}.pre-standardization-$(date +%s)"
cp "${SCRIPT_TO_STANDARDIZE}" "${BACKUP}"
echo "✓ Created backup: ${BACKUP}"

# Extract script name
SCRIPT_NAME=$(basename "${SCRIPT_TO_STANDARDIZE}" .sh)

# Create standardized version
TEMP_FILE=$(mktemp)

cat > "${TEMP_FILE}" << 'HEADER'
#!/usr/bin/env bash
#
# Script: SCRIPT_NAME_PLACEHOLDER
# Description: DESCRIPTION_PLACEHOLDER
# Version: 1.0.0

# Source standard header
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/standard_header.sh" 2>/dev/null || {
    echo "Warning: Could not source standard header"
}

# Script metadata
SCRIPT_NAME="SCRIPT_NAME_PLACEHOLDER"
SCRIPT_VERSION="1.0.0"
SCRIPT_DESCRIPTION="DESCRIPTION_PLACEHOLDER"

HEADER

# Replace placeholders
sed -i "s/SCRIPT_NAME_PLACEHOLDER/${SCRIPT_NAME}/g" "${TEMP_FILE}"

# Extract description from original script if available
DESCRIPTION=$(grep -m1 "^# Description:" "${SCRIPT_TO_STANDARDIZE}" | cut -d: -f2- | xargs || echo "Auto-standardized script")
sed -i "s/DESCRIPTION_PLACEHOLDER/${DESCRIPTION}/g" "${TEMP_FILE}"

# Append original script content (skip shebang and basic header comments)
awk '
    BEGIN { skip = 1 }
    /^#!/ { next }
    /^# (Description|Author|Version|Date):/ { next }
    /^#={3,}/ { next }
    /^$/ && skip { next }
    { skip = 0; print }
' "${SCRIPT_TO_STANDARDIZE}" >> "${TEMP_FILE}"

# Add main function wrapper if not present
if ! grep -q "^main()" "${TEMP_FILE}"; then
    echo "" >> "${TEMP_FILE}"
    echo "# Call main if script is executed directly" >> "${TEMP_FILE}"
    echo 'if [ "${BASH_SOURCE[0]}" = "${0}" ]; then' >> "${TEMP_FILE}"
    echo '    display_header' >> "${TEMP_FILE}"
    echo '    # Original script content runs here' >> "${TEMP_FILE}"
    echo 'fi' >> "${TEMP_FILE}"
fi

# Replace with standardized version
mv "${TEMP_FILE}" "${SCRIPT_TO_STANDARDIZE}"
chmod +x "${SCRIPT_TO_STANDARDIZE}"

echo "✓ Standardized: ${SCRIPT_TO_STANDARDIZE}"
echo "✓ Backup saved: ${BACKUP}"
echo ""
echo "Review the changes and test the script!"
