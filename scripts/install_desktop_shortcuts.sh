#!/usr/bin/env bash
#
# Install desktop shortcuts for hypervisor menu access
# Useful when using GNOME desktop
#
set -euo pipefail

DESKTOP_DIR="$HOME/Desktop"

echo "Installing Hypervisor Desktop Shortcuts"
echo "========================================"
echo ""

# Create Desktop directory if it doesn't exist
if [[ ! -d "$DESKTOP_DIR" ]]; then
  echo "Creating Desktop directory..."
  mkdir -p "$DESKTOP_DIR"
fi

# Copy desktop files
echo "Installing shortcuts..."

# Main menu shortcut
cat > "$DESKTOP_DIR/Hypervisor-Menu.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Hypervisor Console Menu
Comment=Main hypervisor management menu
Exec=gnome-terminal -- /etc/hypervisor/scripts/menu.sh
Icon=utilities-terminal
Terminal=false
Categories=System;Utility;
EOF
chmod +x "$DESKTOP_DIR/Hypervisor-Menu.desktop"
echo "✓ Hypervisor Console Menu"

# Setup wizard shortcut
cat > "$DESKTOP_DIR/Hypervisor-Setup.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Hypervisor Setup Wizard
Comment=Configure networking, ISOs, and VMs
Exec=gnome-terminal -- /etc/hypervisor/scripts/setup_wizard.sh
Icon=system-software-install
Terminal=false
Categories=System;Settings;
EOF
chmod +x "$DESKTOP_DIR/Hypervisor-Setup.desktop"
echo "✓ Hypervisor Setup Wizard"

# Network setup shortcut
cat > "$DESKTOP_DIR/Network-Setup.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Network Foundation Setup
Comment=Configure network bridges and interfaces
Exec=gnome-terminal -- sudo /etc/hypervisor/scripts/foundational_networking_setup.sh
Icon=network-wired
Terminal=false
Categories=System;Settings;Network;
EOF
chmod +x "$DESKTOP_DIR/Network-Setup.desktop"
echo "✓ Network Foundation Setup"

# Dashboard shortcut
cat > "$DESKTOP_DIR/Hypervisor-Dashboard.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Hypervisor Dashboard
Comment=GUI dashboard for VM management
Exec=/etc/hypervisor/scripts/management_dashboard.sh
Icon=computer
Terminal=false
Categories=System;Utility;
EOF
chmod +x "$DESKTOP_DIR/Hypervisor-Dashboard.desktop"
echo "✓ Hypervisor Dashboard"

# Trust the desktop files (GNOME security)
if command -v gio >/dev/null 2>&1; then
  echo ""
  echo "Trusting desktop files..."
  gio set "$DESKTOP_DIR/Hypervisor-Menu.desktop" "metadata::trusted" yes 2>/dev/null || true
  gio set "$DESKTOP_DIR/Hypervisor-Setup.desktop" "metadata::trusted" yes 2>/dev/null || true
  gio set "$DESKTOP_DIR/Network-Setup.desktop" "metadata::trusted" yes 2>/dev/null || true
  gio set "$DESKTOP_DIR/Hypervisor-Dashboard.desktop" "metadata::trusted" yes 2>/dev/null || true
fi

echo ""
echo "✓ Desktop shortcuts installed successfully!"
echo ""
echo "You should now see hypervisor icons on your desktop."
echo "Double-click any icon to access hypervisor management."
echo ""
echo "Shortcuts installed:"
echo "  • Hypervisor Console Menu (main menu)"
echo "  • Hypervisor Setup Wizard (networking, ISOs, VMs)"
echo "  • Network Foundation Setup (network configuration)"
echo "  • Hypervisor Dashboard (GUI management)"
