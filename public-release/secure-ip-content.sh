#!/bin/bash
# Secure Intellectual Property Content Script
# Separates and protects AI/development documentation

set -e

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Directories
WORKSPACE="/workspace"
PRIVATE_DIR="$WORKSPACE/.private-ip"
PUBLIC_DIR="$WORKSPACE/public-release"

echo -e "${CYAN}${BOLD}Securing Intellectual Property Content${NC}"
echo "======================================"
echo

# Function to create secure directory
create_secure_directory() {
    local dir=$1
    echo -e "${YELLOW}Creating secure directory: $dir${NC}"
    
    # Create directory with restricted permissions
    mkdir -p "$dir"
    chmod 700 "$dir"  # Only owner can read/write/execute
    
    # Create .gitignore to prevent accidental commits
    cat > "$dir/.gitignore" << EOF
# Ignore everything in this directory
*
# Except this .gitignore file
!.gitignore
EOF
    
    # Create README for the directory
    cat > "$dir/README.md" << EOF
# PRIVATE - INTELLECTUAL PROPERTY

This directory contains proprietary documentation and materials.
DO NOT DISTRIBUTE OR SHARE.

Owner: System Administrator
Access: Restricted
EOF
    chmod 600 "$dir/README.md"
}

# Create directory structure
echo -e "${BOLD}Setting up directory structure...${NC}"
create_secure_directory "$PRIVATE_DIR"
create_secure_directory "$PRIVATE_DIR/ai-development"
create_secure_directory "$PRIVATE_DIR/audit-reports"
create_secure_directory "$PRIVATE_DIR/implementation-details"

mkdir -p "$PUBLIC_DIR"
mkdir -p "$PUBLIC_DIR/docs"
mkdir -p "$PUBLIC_DIR/scripts"

# Move sensitive AI/development documents to private directory
echo -e "${BOLD}Moving AI and development documents to private storage...${NC}"

# AI Development documents
AI_DOCS=(
    "docs/development/AI-Development-Best-Practices.md"
    "docs/development/AI-LESSONS-LEARNED.md"
    "docs/development/AI-QUICK-REFERENCE.md"
    "docs/development/ADVANCED-PATTERNS-INTEGRATION-GUIDE.md"
)

for doc in "${AI_DOCS[@]}"; do
    if [[ -f "$WORKSPACE/$doc" ]]; then
        echo -e "${BLUE}Securing: $(basename $doc)${NC}"
        mv "$WORKSPACE/$doc" "$PRIVATE_DIR/ai-development/" 2>/dev/null || true
        chmod 600 "$PRIVATE_DIR/ai-development/$(basename $doc)"
    fi
done

# Audit and test reports
AUDIT_DOCS=(
    "docs/reports/AUDIT-RESULTS.md"
    "docs/reports/FEATURE-TEST-REPORT.md"
    "docs/reports/FINAL-AUDIT-SUMMARY.md"
    "docs/reports/QA_VALIDATION_REPORT.md"
    "docs/reports/IMPLEMENTATION-VALIDATED.md"
    "security-platform-audit.sh"
)

for doc in "${AUDIT_DOCS[@]}"; do
    if [[ -f "$WORKSPACE/$doc" ]]; then
        echo -e "${BLUE}Securing: $(basename $doc)${NC}"
        mv "$WORKSPACE/$doc" "$PRIVATE_DIR/audit-reports/" 2>/dev/null || true
        chmod 600 "$PRIVATE_DIR/audit-reports/$(basename $doc)"
    fi
done

# Implementation details
IMPL_DOCS=(
    "docs/implementation/COMPLETE-IMPLEMENTATION-SUMMARY.md"
    "docs/implementation/COMPLETE-IMPLEMENTATION-VERIFICATION.md"
    "docs/implementation/FINAL-IMPLEMENTATION-REPORT.md"
    "docs/implementation/IMPLEMENTATION-STATUS.md"
    "docs/implementation/system-improvement-implementation.md"
    "docs/FILE-ORGANIZATION-SUMMARY.md"
)

for doc in "${IMPL_DOCS[@]}"; do
    if [[ -f "$WORKSPACE/$doc" ]]; then
        echo -e "${BLUE}Securing: $(basename $doc)${NC}"
        mv "$WORKSPACE/$doc" "$PRIVATE_DIR/implementation-details/" 2>/dev/null || true
        chmod 600 "$PRIVATE_DIR/implementation-details/$(basename $doc)"
    fi
done

# Copy public-safe files to release directory
echo
echo -e "${BOLD}Preparing public release directory...${NC}"

# Copy only public-safe documentation
PUBLIC_DOCS=(
    "README.md"
    "docs/guides/SECURITY-QUICKSTART.md"
    "docs/guides/ENTERPRISE_QUICK_START.md"
    "docs/deployment/DEPLOYMENT-GUIDE.md"
    "docs/deployment/RELEASE-NOTES-V2.0.md"
    "docs/PLATFORM-OVERVIEW.md"
    "docs/SCALABLE-SECURITY-FRAMEWORK.md"
)

for doc in "${PUBLIC_DOCS[@]}"; do
    if [[ -f "$WORKSPACE/$doc" ]]; then
        echo -e "${GREEN}Public: $(basename $doc)${NC}"
        mkdir -p "$(dirname "$PUBLIC_DIR/$doc")"
        cp "$WORKSPACE/$doc" "$PUBLIC_DIR/$doc" 2>/dev/null || true
    fi
done

# Copy main scripts (but not audit/test scripts)
PUBLIC_SCRIPTS=(
    "security-platform-deploy.sh"
    "modular-security-framework.sh"
    "console-enhancements.sh"
    "profile-selector.sh"
    "module-config-schema.yaml"
)

for script in "${PUBLIC_SCRIPTS[@]}"; do
    if [[ -f "$WORKSPACE/$script" ]]; then
        echo -e "${GREEN}Public: $script${NC}"
        cp "$WORKSPACE/$script" "$PUBLIC_DIR/$script" 2>/dev/null || true
    fi
done

# Create a sanitized docs index for public release
cat > "$PUBLIC_DIR/docs/README.md" << 'EOF'
# Security Platform Documentation

## Available Documentation

### 🚀 Getting Started
- [Security Quick Start](guides/SECURITY-QUICKSTART.md)
- [Enterprise Quick Start](guides/ENTERPRISE_QUICK_START.md)

### 📦 Deployment
- [Deployment Guide](deployment/DEPLOYMENT-GUIDE.md)
- [Release Notes](deployment/RELEASE-NOTES-V2.0.md)

### 📋 Reference
- [Platform Overview](PLATFORM-OVERVIEW.md)
- [Architecture Guide](SCALABLE-SECURITY-FRAMEWORK.md)

---

For support, please contact: support@example.com
EOF

# Create access control script
cat > "$PRIVATE_DIR/access-control.sh" << 'EOF'
#!/bin/bash
# Access control for private IP content

check_access() {
    local user=$(whoami)
    local allowed_user="${ALLOWED_USER:-root}"
    
    if [[ "$user" != "$allowed_user" ]]; then
        echo "Access denied. This content is restricted."
        exit 1
    fi
}

# Check access before any operation
check_access

case "$1" in
    list)
        find . -type f -name "*.md" -o -name "*.sh" | sort
        ;;
    show)
        if [[ -f "$2" ]]; then
            less "$2"
        else
            echo "File not found: $2"
        fi
        ;;
    *)
        echo "Usage: $0 {list|show <file>}"
        ;;
esac
EOF
chmod 700 "$PRIVATE_DIR/access-control.sh"

# Create encryption script for extra security
cat > "$PRIVATE_DIR/encrypt-content.sh" << 'EOF'
#!/bin/bash
# Encrypt sensitive content

PRIVATE_DIR="$(dirname "$0")"

echo "Encrypting private content..."

# Create encrypted archive
tar -czf - "$PRIVATE_DIR"/{ai-development,audit-reports,implementation-details} | \
    openssl enc -aes-256-cbc -salt -out "$PRIVATE_DIR/private-content.enc"

echo "Content encrypted to: private-content.enc"
echo "To decrypt: openssl enc -d -aes-256-cbc -in private-content.enc | tar -xzf -"
EOF
chmod 700 "$PRIVATE_DIR/encrypt-content.sh"

# Create summary of what was secured
echo
echo -e "${BOLD}${CYAN}Security Summary${NC}"
echo "==============="
echo
echo -e "${GREEN}Private/Secured Content:${NC}"
echo "  Location: $PRIVATE_DIR"
echo "  Permissions: 700 (owner only)"
echo "  Contents:"
find "$PRIVATE_DIR" -type f -name "*.md" -o -name "*.sh" | grep -v ".gitignore" | sort | sed 's|^|    |'

echo
echo -e "${BLUE}Public Release Content:${NC}"
echo "  Location: $PUBLIC_DIR"
echo "  Safe for distribution"
echo

# Create distribution package
echo -e "${BOLD}Creating distribution package...${NC}"
cd "$PUBLIC_DIR"
tar -czf "$WORKSPACE/security-platform-public-v2.0.tar.gz" .
cd - >/dev/null

echo
echo -e "${GREEN}${BOLD}✓ Content secured successfully!${NC}"
echo
echo "Next steps:"
echo "1. Your private IP content is in: $PRIVATE_DIR"
echo "2. Public distribution package: security-platform-public-v2.0.tar.gz"
echo "3. To encrypt private content: $PRIVATE_DIR/encrypt-content.sh"
echo "4. To access private content: $PRIVATE_DIR/access-control.sh"
echo
echo -e "${YELLOW}Remember to:${NC}"
echo "- Back up $PRIVATE_DIR to secure storage"
echo "- Never commit $PRIVATE_DIR to public repositories"
echo "- Use encryption for extra security"