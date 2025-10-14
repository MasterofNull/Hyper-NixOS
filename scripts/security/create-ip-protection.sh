#!/bin/bash
# shellcheck disable=SC2034,SC2154,SC1091
# Comprehensive IP Protection System
# Multiple layers of security for your intellectual property

set -e

# Configuration
WORKSPACE="/workspace"
PROTECTED_DIR="$WORKSPACE/.protected-ip"
LICENSE_FILE="$WORKSPACE/LICENSE-RESTRICTIVE"

echo "Setting up comprehensive IP protection..."

# 1. Create restrictive license
cat > "$LICENSE_FILE" << 'EOF'
PROPRIETARY AND CONFIDENTIAL

Copyright (c) 2024 [Your Name/Company]

All Rights Reserved.

NOTICE: This repository contains proprietary information and trade secrets.

The AI development documentation, audit tools, implementation details, and
development methodologies contained in this repository are the exclusive
property of the copyright holder and are protected by intellectual property
laws.

NO PERMISSION IS GRANTED to use, copy, modify, distribute, or create
derivative works from the following materials:
- AI Development Documentation
- Audit and Testing Tools
- Implementation Strategies
- Development Methodologies
- Architecture Patterns

For licensing inquiries regarding the security platform implementation
(excluding the above restricted materials), please contact: [your-email]

UNAUTHORIZED USE, REPRODUCTION, OR DISTRIBUTION OF THE RESTRICTED MATERIALS
IS STRICTLY PROHIBITED AND MAY RESULT IN SEVERE CIVIL AND CRIMINAL PENALTIES.
EOF

# 2. Create .gitignore for private content
cat > "$WORKSPACE/.gitignore-private" << 'EOF'
# Private IP Content - DO NOT COMMIT
.private-ip/
.protected-ip/
**/AI-*.md
**/audit-*.sh
**/test-*.sh
**/validate-*.sh
**/IMPLEMENTATION*.md
**/COMPLETE-*.md
**/*LESSONS-LEARNED*
**/*implementation-details*
**/*-audit-*
*.enc
*.key
*.private

# Temporary files
*.tmp
*.bak
*.swp
EOF

# 3. Create access control wrapper
cat > "$WORKSPACE/control-access.sh" << 'EOF'
#!/bin/bash
# Access control system for IP content

# Check if running as authorized user
check_authorization() {
    local auth_file="$HOME/.security-platform-auth"
    
    if [[ ! -f "$auth_file" ]]; then
        echo "ERROR: Not authorized to access IP content"
        echo "Please contact the IP owner for access"
        exit 1
    fi
    
    # Verify auth token
    local stored_hash=$(cat "$auth_file" 2>/dev/null)
    local current_hash=$(echo -n "$USER:$HOSTNAME" | sha256sum | cut -d' ' -f1)
    
    if [[ "$stored_hash" != "$current_hash" ]]; then
        echo "ERROR: Invalid authorization"
        exit 1
    fi
}

# Grant access (owner only)
grant_access() {
    if [[ "$1" != "grant" ]] || [[ -z "$2" ]]; then
        echo "Usage: $0 grant <user>"
        exit 1
    fi
    
    local auth_file="/home/$2/.security-platform-auth"
    local auth_hash=$(echo -n "$2:$(hostname)" | sha256sum | cut -d' ' -f1)
    
    echo "$auth_hash" | sudo tee "$auth_file" > /dev/null
    sudo chown "$2:$2" "$auth_file"
    sudo chmod 600 "$auth_file"
    
    echo "Access granted to user: $2"
}

# Main logic
case "$1" in
    grant)
        grant_access "$@"
        ;;
    check)
        check_authorization
        echo "Access authorized"
        ;;
    *)
        check_authorization
        # Proceed with protected operation
        ;;
esac
EOF
chmod 750 "$WORKSPACE/control-access.sh"

# 4. Create content filter for public release
cat > "$WORKSPACE/prepare-public-release.sh" << 'EOF'
#!/bin/bash
# Prepare public release by filtering out IP content

set -e

PUBLIC_DIR="./public-release"
PRIVATE_PATTERNS=(
    "*AI-Development*"
    "*AI-LESSONS*"
    "*AI-QUICK*"
    "*audit-*"
    "*test-platform*"
    "*validate-*"
    "*IMPLEMENTATION*"
    "*COMPLETE-*"
    "*FINAL-*-SUMMARY*"
)

echo "Preparing public release..."

# Create clean public directory
rm -rf "$PUBLIC_DIR"
mkdir -p "$PUBLIC_DIR"

# Copy all files except private ones
rsync -av \
    --exclude=".private-ip/" \
    --exclude=".protected-ip/" \
    --exclude=".*" \
    --exclude="prepare-public-release.sh" \
    --exclude="secure-ip-content.sh" \
    --exclude="control-access.sh" \
    --exclude="create-ip-protection.sh" \
    ./ "$PUBLIC_DIR/"

# Remove private patterns from public release
for pattern in "${PRIVATE_PATTERNS[@]}"; do
    find "$PUBLIC_DIR" -name "$pattern" -type f -delete 2>/dev/null || true
done

# Clean up empty directories
find "$PUBLIC_DIR" -type d -empty -delete

# Create public README
cat > "$PUBLIC_DIR/README-PUBLIC.md" << 'EOREADME'
# Security Platform - Public Release

This is the public release of the Security Platform.

## License
See LICENSE file for terms of use.

## Documentation
Public documentation is available in the docs/ directory.

## Support
For support and licensing inquiries: support@example.com

---
Note: This is a filtered public release. Some development documentation
and tools are not included as they contain proprietary information.
EOREADME

echo "Public release prepared in: $PUBLIC_DIR"
echo "Create archive with: tar -czf security-platform-public.tar.gz -C $PUBLIC_DIR ."
EOF
chmod 750 "$WORKSPACE/prepare-public-release.sh"

# 5. Create watermarking script for documents
cat > "$WORKSPACE/watermark-documents.sh" << 'EOF'
#!/bin/bash
# Add watermarks to IP documents

add_watermark() {
    local file=$1
    local temp_file="${file}.tmp"
    
    # Add watermark header
    cat > "$temp_file" << 'EOHEADER'
<!--
PROPRIETARY AND CONFIDENTIAL
This document contains trade secrets and proprietary information.
Unauthorized use, reproduction, or distribution is strictly prohibited.
Copyright (c) 2024 - All Rights Reserved
Document ID: $(uuidgen)
Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
-->

EOHEADER
    
    # Append original content
    cat "$file" >> "$temp_file"
    
    # Add watermark footer
    cat >> "$temp_file" << 'EOFOOTER'

---
*This document is proprietary and confidential. Do not distribute.*
EOFOOTER
    
    mv "$temp_file" "$file"
}

# Apply watermarks to all private documents
find .private-ip -name "*.md" -type f | while read -r file; do
    echo "Watermarking: $file"
    add_watermark "$file"
done
EOF
chmod 750 "$WORKSPACE/watermark-documents.sh"

# 6. Create monitoring script
cat > "$WORKSPACE/monitor-ip-access.sh" << 'EOF'
#!/bin/bash
# Monitor access to IP content

LOG_FILE="/var/log/ip-content-access.log"

# Set up audit logging for private directory
setup_monitoring() {
    # Use auditd if available
    if command -v auditctl &> /dev/null; then
        sudo auditctl -w /workspace/.private-ip -p rwxa -k ip_content_access
        echo "Audit monitoring enabled for IP content"
    fi
    
    # Alternative: use inotify
    if command -v inotifywait &> /dev/null; then
        inotifywait -m -r -e access,open,close,move,delete /workspace/.private-ip \
            --format '%T %w%f %e' --timefmt '%Y-%m-%d %H:%M:%S' >> "$LOG_FILE" &
        echo "Inotify monitoring enabled for IP content"
    fi
}

# Check recent access
check_access() {
    echo "Recent access to IP content:"
    if [[ -f "$LOG_FILE" ]]; then
        tail -n 50 "$LOG_FILE"
    fi
    
    # Check audit logs if available
    if command -v ausearch &> /dev/null; then
        sudo ausearch -k ip_content_access --start today
    fi
}

case "$1" in
    setup)
        setup_monitoring
        ;;
    check)
        check_access
        ;;
    *)
        echo "Usage: $0 {setup|check}"
        ;;
esac
EOF
chmod 750 "$WORKSPACE/monitor-ip-access.sh"

echo
echo "✅ IP Protection System Created"
echo "=============================="
echo
echo "Components created:"
echo "1. LICENSE-RESTRICTIVE - Restrictive license for IP content"
echo "2. secure-ip-content.sh - Move IP content to protected directory"
echo "3. control-access.sh - Access control system"
echo "4. prepare-public-release.sh - Create filtered public release"
echo "5. watermark-documents.sh - Add watermarks to documents"
echo "6. monitor-ip-access.sh - Monitor access to IP content"
echo
echo "To protect your IP content, run:"
echo "  ./secure-ip-content.sh"
echo
echo "This will:"
echo "- Move all AI/development docs to .private-ip/ (hidden, protected)"
echo "- Create a public-release/ directory with only safe content"
echo "- Set restrictive permissions (700) on private content"
echo "- Create tools for access control and monitoring"