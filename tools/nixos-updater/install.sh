#!/usr/bin/env bash
#
# NixOS Updater Installation Script
# Install the standalone updater on any NixOS system

set -euo pipefail

readonly TOOL_NAME="nixos-updater"
readonly VERSION="2.0.0"
readonly INSTALL_PREFIX="${NIXOS_UPDATER_PREFIX:-/usr/local}"
readonly INSTALL_BIN="$INSTALL_PREFIX/bin"
readonly INSTALL_LIB="$INSTALL_PREFIX/lib/$TOOL_NAME"
readonly INSTALL_HOOKS="/etc/$TOOL_NAME/hooks"
readonly INSTALL_DOC="/usr/share/doc/$TOOL_NAME"

echo "═══════════════════════════════════════════════════════════════"
echo "  NixOS Updater v$VERSION - Installation"
echo "═══════════════════════════════════════════════════════════════"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "⚠ This script should be run as root"
    echo "  Re-running with sudo..."
    exec sudo "$0" "$@"
fi

# Detect script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installation settings:"
echo "  Install prefix: $INSTALL_PREFIX"
echo "  Binary: $INSTALL_BIN/$TOOL_NAME"
echo "  Library: $INSTALL_LIB"
echo "  Hooks: $INSTALL_HOOKS"
echo "  Documentation: $INSTALL_DOC"
echo

# Create directories
echo "→ Creating directories..."
mkdir -p "$INSTALL_BIN"
mkdir -p "$INSTALL_LIB"
mkdir -p "$INSTALL_HOOKS"/{pre-check,post-check,pre-update,post-update,pre-upgrade,post-upgrade,post-rollback}
mkdir -p "$INSTALL_DOC"
mkdir -p "/var/log/$TOOL_NAME"

# Install main script
echo "→ Installing main script..."
install -m 755 "$SCRIPT_DIR/$TOOL_NAME" "$INSTALL_BIN/$TOOL_NAME"

# Install library
if [[ -d "$SCRIPT_DIR/lib" ]]; then
    echo "→ Installing library files..."
    cp -r "$SCRIPT_DIR/lib" "$INSTALL_LIB/"
    chmod 644 "$INSTALL_LIB/lib"/*.sh
fi

# Install documentation
if [[ -f "$SCRIPT_DIR/README.md" ]]; then
    echo "→ Installing documentation..."
    cp "$SCRIPT_DIR/README.md" "$INSTALL_DOC/"
fi

if [[ -d "$SCRIPT_DIR/docs" ]]; then
    cp -r "$SCRIPT_DIR/docs"/* "$INSTALL_DOC/" 2>/dev/null || true
fi

# Install example hooks
if [[ -d "$SCRIPT_DIR/hooks-examples" ]]; then
    echo "→ Installing example hooks..."
    cp -r "$SCRIPT_DIR/hooks-examples"/* "$INSTALL_HOOKS/" 2>/dev/null || true
fi

# Create example config
if [[ ! -f "/etc/$TOOL_NAME/config" ]]; then
    echo "→ Creating default configuration..."
    mkdir -p "/etc/$TOOL_NAME"
    cat > "/etc/$TOOL_NAME/config" << 'EOF'
# NixOS Updater Configuration

# Log retention (days)
LOG_RETENTION_DAYS=30

# Automatic garbage collection after update
AUTO_GARBAGE_COLLECT=true
KEEP_GENERATIONS=5

# Backup before major upgrades
AUTO_BACKUP=true

# Notification settings (if available)
ENABLE_NOTIFICATIONS=false

# Hook execution timeout (seconds)
HOOK_TIMEOUT=300
EOF
fi

# Create systemd timer (optional automatic updates)
echo "→ Installing systemd timer (optional)..."
cat > /etc/systemd/system/nixos-updater-check.timer << 'EOF'
[Unit]
Description=Check for NixOS updates daily
Documentation=man:nixos-updater(1)

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

cat > /etc/systemd/system/nixos-updater-check.service << 'EOF'
[Unit]
Description=Check for NixOS updates
Documentation=man:nixos-updater(1)

[Service]
Type=oneshot
ExecStart=/usr/local/bin/nixos-updater check
User=root
EOF

echo
echo "✓ Installation complete!"
echo
echo "Quick start:"
echo "  nixos-updater wizard       # Interactive mode"
echo "  nixos-updater check        # Check for updates"
echo "  nixos-updater update       # Update system"
echo "  nixos-updater help         # Show all commands"
echo
echo "Optional: Enable automatic update checks"
echo "  systemctl enable nixos-updater-check.timer"
echo "  systemctl start nixos-updater-check.timer"
echo
echo "Documentation: $INSTALL_DOC"
echo "Configuration: /etc/$TOOL_NAME/config"
echo "Hooks: $INSTALL_HOOKS"
echo
echo "═══════════════════════════════════════════════════════════════"
