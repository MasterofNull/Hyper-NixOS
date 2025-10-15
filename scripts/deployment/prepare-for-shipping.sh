#!/bin/bash
# shellcheck disable=SC2034,SC2154,SC1091
# Prepare Security Platform for Shipping
# Separates private IP from public distribution

set -e

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

echo -e "${CYAN}${BOLD}Preparing Security Platform for Shipping${NC}"
echo "========================================"
echo

# Create directories
echo -e "${YELLOW}Creating directory structure...${NC}"
mkdir -p private-ip/{ai-context,reports}
mkdir -p public-release/{docs,scripts}

# Move private IP content
echo -e "${YELLOW}Securing private IP content...${NC}"

# Move audit/test reports to private
REPORTS=(
    "docs/reports/AUDIT-RESULTS.md"
    "docs/reports/FEATURE-TEST-REPORT.md"
    "docs/reports/FINAL-AUDIT-SUMMARY.md"
    "docs/reports/QA_VALIDATION_REPORT.md"
    "docs/reports/IMPLEMENTATION-VALIDATED.md"
    "AUDIT-SUMMARY.md"
)

for report in "${REPORTS[@]}"; do
    if [[ -f "$report" ]]; then
        echo "  Moving to private: $(basename $report)"
        mv "$report" private-ip/reports/ 2>/dev/null || true
    fi
done

# Move any AI context docs (if they exist)
if ls *AI-CONTEXT* *AI-PROMPT* *hysteresis* 2>/dev/null; then
    mv *AI-CONTEXT* *AI-PROMPT* *hysteresis* private-ip/ai-context/ 2>/dev/null || true
fi

# Copy public content
echo -e "${YELLOW}Preparing public release...${NC}"

# Copy main scripts
cp -v *.sh public-release/ 2>/dev/null || true
cp -v *.yaml public-release/ 2>/dev/null || true

# Copy public documentation
mkdir -p public-release/docs/{guides,deployment,development,implementation}

# Public guides
cp -v docs/guides/* public-release/docs/guides/ 2>/dev/null || true

# Deployment docs
cp -v docs/deployment/* public-release/docs/deployment/ 2>/dev/null || true

# Development docs (platform development, not AI context)
cp -v docs/development/*.md public-release/docs/development/ 2>/dev/null || true

# Implementation docs (architecture, not verification reports)
for doc in docs/implementation/*.md; do
    if [[ -f "$doc" ]] && ! grep -q "VERIFICATION\|COMPLETE-\|REPORT" "$doc"; then
        cp -v "$doc" public-release/docs/implementation/
    fi
done

# Copy general docs
cp -v docs/*.md public-release/docs/ 2>/dev/null || true
cp -v README.md public-release/ 2>/dev/null || true

# Copy scripts directory
cp -r scripts public-release/ 2>/dev/null || true

# Create .gitignore for private content
cat > .gitignore << 'EOF'
# Private IP Content
private-ip/
**/private-ip/

# Temporary files
*.tmp
*.bak
*.swp
*.log

# OS files
.DS_Store
Thumbs.db
EOF

# Create shipping manifest
cat > public-release/MANIFEST.txt << EOF
Security Platform v2.0 - Public Release
======================================

Release Date: $(date)
Platform Version: 2.0.0

This package contains:
- Security platform deployment scripts
- User and developer documentation  
- Module implementations
- Configuration examples

For licensing and support: support@example.com

Note: This is the public release. Some internal documentation
and test reports are not included as they contain proprietary
information.
EOF

# Create archive
echo
echo -e "${YELLOW}Creating distribution archive...${NC}"
# Ensure releases directory exists
mkdir -p ../releases
cd public-release
tar -czf ../releases/security-platform-v2.0-public.tar.gz .
cd ..

# Summary
echo
echo -e "${GREEN}${BOLD}✅ Shipping Preparation Complete!${NC}"
echo
echo "📦 Public Release Archive: releases/security-platform-v2.0-public.tar.gz"
echo "   Size: $(du -h releases/security-platform-v2.0-public.tar.gz | cut -f1)"
echo "   Files: $(tar -tzf releases/security-platform-v2.0-public.tar.gz | wc -l)"
echo
echo "🔒 Private IP Content: private-ip/"
echo "   - AI context documentation"
echo "   - Audit/test reports"
echo "   - Implementation verification"
echo
echo "Ready to ship! The public archive contains only distributable content."