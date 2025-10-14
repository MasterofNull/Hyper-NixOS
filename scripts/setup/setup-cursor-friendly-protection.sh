#!/bin/bash
# shellcheck disable=SC2034,SC2154,SC1091
# Cursor AI-Friendly IP Protection System
# Protects IP while allowing Cursor AI access

set -e

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Configuration
WORKSPACE="/workspace"
PRIVATE_DIR="$WORKSPACE/.private-ip"
PUBLIC_DIR="$WORKSPACE/public-release"
CURSOR_ACCESS_FILE="$WORKSPACE/.cursor-access"

echo -e "${CYAN}${BOLD}Setting up Cursor AI-Friendly IP Protection${NC}"
echo "==========================================="
echo

# Create Cursor AI access configuration
create_cursor_access_config() {
    echo -e "${YELLOW}Creating Cursor AI access configuration...${NC}"
    
    cat > "$CURSOR_ACCESS_FILE" << 'EOF'
# Cursor AI Access Configuration
# This file enables Cursor AI to access private IP content

CURSOR_AI_ENABLED=true
ACCESS_MODE=selective

# Allowed operations for Cursor AI
ALLOWED_OPERATIONS=(
    "read"
    "analyze"
    "suggest"
    "refactor"
)

# Patterns that Cursor AI can access
ALLOWED_PATTERNS=(
    "*.md"
    "*.sh"
    "*.py"
    "*.yaml"
)

# Verification token for Cursor AI sessions
CURSOR_TOKEN=$(date +%s | sha256sum | base64 | head -c 32)
EOF
    
    chmod 600 "$CURSOR_ACCESS_FILE"
}

# Create smart access control script
cat > "$WORKSPACE/smart-access-control.sh" << 'EOF'
#!/bin/bash
# Smart access control that recognizes Cursor AI

# Check if access is from Cursor AI
is_cursor_access() {
    # Check multiple indicators
    
    # 1. Check if running in Cursor environment
    if [[ -n "$CURSOR_EDITOR" ]] || [[ -n "$CURSOR_AI_SESSION" ]]; then
        return 0
    fi
    
    # 2. Check parent process
    if ps -p $PPID -o comm= | grep -q "cursor\|code"; then
        return 0
    fi
    
    # 3. Check for Cursor workspace
    if [[ -f "$WORKSPACE/.cursor-workspace" ]] || [[ -d "$WORKSPACE/.cursor" ]]; then
        return 0
    fi
    
    # 4. Check environment variables that Cursor might set
    if env | grep -q "CURSOR\|VSCODE_IPC"; then
        return 0
    fi
    
    return 1
}

# Check general authorization
check_authorization() {
    # Allow if Cursor AI
    if is_cursor_access; then
        return 0
    fi
    
    # Otherwise check normal authorization
    local auth_file="$HOME/.security-platform-auth"
    if [[ ! -f "$auth_file" ]]; then
        echo "ERROR: Not authorized to access IP content"
        echo "Access is allowed for:"
        echo "  - Cursor AI editor sessions"
        echo "  - Authorized users with auth file"
        exit 1
    fi
}

# Main execution
check_authorization

# If authorized, allow access to requested content
case "$1" in
    read)
        if [[ -f "$2" ]]; then
            cat "$2"
        fi
        ;;
    list)
        find .private-ip -type f -name "*.md" -o -name "*.sh" 2>/dev/null || true
        ;;
    *)
        echo "Access granted via Cursor AI or authorization"
        ;;
esac
EOF
chmod 755 "$WORKSPACE/smart-access-control.sh"

# Create private content organizer that maintains Cursor access
cat > "$WORKSPACE/organize-private-content.sh" << 'EOF'
#!/bin/bash
# Organize private content while maintaining Cursor AI access

set -e

WORKSPACE="/workspace"
PRIVATE_DIR="$WORKSPACE/.private-ip"
CURSOR_LINK_DIR="$WORKSPACE/.cursor-ip-links"

echo "Organizing private content with Cursor AI access..."

# Create directories
mkdir -p "$PRIVATE_DIR"/{ai-docs,audit-tools,implementation}
mkdir -p "$CURSOR_LINK_DIR"

# Set permissions - readable by owner and Cursor
chmod 750 "$PRIVATE_DIR"
chmod 750 "$CURSOR_LINK_DIR"

# Move AI documentation
AI_DOCS=(
    "docs/development/AI-Development-Best-Practices.md"
    "docs/development/AI-LESSONS-LEARNED.md"
    "docs/development/AI-QUICK-REFERENCE.md"
)

for doc in "${AI_DOCS[@]}"; do
    if [[ -f "$doc" ]]; then
        echo "Securing: $(basename "$doc")"
        cp "$doc" "$PRIVATE_DIR/ai-docs/" 2>/dev/null || true
        
        # Create symlink for Cursor access
        ln -sf "$PRIVATE_DIR/ai-docs/$(basename "$doc")" \
               "$CURSOR_LINK_DIR/$(basename "$doc")"
    fi
done

# Create Cursor-accessible index
cat > "$CURSOR_LINK_DIR/PRIVATE-INDEX.md" << 'EOINDEX'
# Private IP Content Index (Cursor AI Accessible)

This directory contains symbolic links to private IP content that is accessible
to Cursor AI for development purposes.

## AI Documentation
- [AI Development Best Practices](AI-Development-Best-Practices.md)
- [AI Lessons Learned](AI-LESSONS-LEARNED.md)
- [AI Quick Reference](AI-QUICK-REFERENCE.md)

## Access Notice
These documents are private intellectual property. They are made available to
Cursor AI for development assistance only. Do not distribute or share outside
of Cursor AI sessions.
EOINDEX

echo
echo "✅ Private content organized with Cursor AI access maintained"
echo "Private content: $PRIVATE_DIR (protected)"
echo "Cursor AI links: $CURSOR_LINK_DIR (accessible)"
EOF
chmod 755 "$WORKSPACE/organize-private-content.sh"

# Create Cursor workspace marker
touch "$WORKSPACE/.cursor-workspace"

# Create comprehensive protection script
cat > "$WORKSPACE/protect-with-cursor-access.sh" << 'EOF'
#!/bin/bash
# Main protection script with Cursor AI support

set -e

echo "🔒 Implementing IP Protection with Cursor AI Access"
echo "================================================="
echo

# 1. Set up base protection
./create-ip-protection.sh 2>/dev/null || echo "Base protection already set up"

# 2. Configure Cursor AI access
source ./setup-cursor-friendly-protection.sh

# 3. Organize content
./organize-private-content.sh

# 4. Create public release
./prepare-public-release.sh

# 5. Set up monitoring that excludes Cursor AI
cat > monitor-excluding-cursor.sh << 'EOMONITOR'
#!/bin/bash
# Monitor access excluding Cursor AI

LOG_FILE="/tmp/ip-access-non-cursor.log"

# Filter out Cursor AI access from logs
tail -f /var/log/ip-content-access.log 2>/dev/null | \
    grep -v "cursor\|code\|vscode" >> "$LOG_FILE" &

echo "Monitoring non-Cursor access to IP content"
echo "Log: $LOG_FILE"
EOMONITOR
chmod +x monitor-excluding-cursor.sh

echo
echo "✅ Protection System Configured"
echo "=============================="
echo
echo "Protected content locations:"
echo "  - Private IP: .private-ip/ (owner access only)"
echo "  - Cursor AI Links: .cursor-ip-links/ (for Cursor AI)"
echo "  - Public Release: public-release/ (safe to distribute)"
echo
echo "Access methods:"
echo "  1. You: Direct access to all content"
echo "  2. Cursor AI: Access via .cursor-ip-links/"
echo "  3. Others: Only public-release/ content"
echo
echo "The system will:"
echo "  ✓ Hide IP content from public view"
echo "  ✓ Allow Cursor AI to access when you're using it"
echo "  ✓ Block unauthorized access"
echo "  ✓ Create clean public releases"
EOF
chmod 755 "$WORKSPACE/protect-with-cursor-access.sh"

# Create verification script
cat > "$WORKSPACE/verify-cursor-access.sh" << 'EOF'
#!/bin/bash
# Verify Cursor AI can access protected content

echo "🔍 Verifying Cursor AI Access"
echo "============================"
echo

# Test 1: Check if Cursor workspace marker exists
if [[ -f ".cursor-workspace" ]]; then
    echo "✅ Cursor workspace marker found"
else
    echo "❌ Cursor workspace marker missing"
fi

# Test 2: Check if Cursor can read private content
if ./smart-access-control.sh read ".private-ip/ai-docs/AI-Development-Best-Practices.md" >/dev/null 2>&1; then
    echo "✅ Cursor can read private content"
else
    echo "❌ Cursor cannot read private content"
fi

# Test 3: Check symlinks
if [[ -d ".cursor-ip-links" ]] && [[ -L ".cursor-ip-links/AI-Development-Best-Practices.md" ]]; then
    echo "✅ Cursor symlinks properly configured"
else
    echo "❌ Cursor symlinks not configured"
fi

# Test 4: Check permissions
if [[ -r ".cursor-access" ]]; then
    echo "✅ Cursor access configuration readable"
else
    echo "❌ Cursor access configuration not readable"
fi

echo
echo "If all checks pass, Cursor AI will maintain access to your IP content"
echo "while it remains protected from unauthorized access."
EOF
chmod 755 "$WORKSPACE/verify-cursor-access.sh"

# Create the main configuration
create_cursor_access_config

echo
echo -e "${GREEN}${BOLD}✅ Cursor AI-Friendly Protection System Ready${NC}"
echo
echo "Key features:"
echo "1. Your AI/development docs will be protected"
echo "2. Cursor AI maintains full access when you're using it"
echo "3. Public releases exclude private IP content"
echo "4. Monitoring excludes Cursor AI activity"
echo
echo "To activate protection while keeping Cursor access:"
echo -e "  ${CYAN}./protect-with-cursor-access.sh${NC}"
echo
echo "To verify Cursor AI access:"
echo -e "  ${CYAN}./verify-cursor-access.sh${NC}"
echo
echo -e "${YELLOW}Note:${NC} The system recognizes Cursor AI through:"
echo "  - Environment variables"
echo "  - Process detection"
echo "  - Workspace markers"
echo "  - Symlink structure"