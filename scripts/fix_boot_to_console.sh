#!/usr/bin/env bash
#
# Fix boot behavior to load console menu instead of GNOME
# Run this if GNOME is auto-starting instead of the console menu
#
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" >&2
  echo "Usage: sudo $0" >&2
  exit 1
fi

echo "═══════════════════════════════════════════════════"
echo "  Fix Boot Behavior: Console Menu First"
echo "═══════════════════════════════════════════════════"
echo ""
echo "This script will:"
echo "  1. Disable GNOME autostart at boot"
echo "  2. Enable console menu at boot (default)"
echo "  3. Install desktop shortcuts for GNOME access"
echo "  4. Rebuild system configuration"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 0
fi

echo ""
echo "Step 1: Configuring boot behavior..."
echo "--------------------------------------"

TARGET_DIR=/var/lib/hypervisor/configuration
mkdir -p "$TARGET_DIR"

# Create gui-local.nix to disable GUI
cat >"$TARGET_DIR/gui-local.nix" <<'NIX'
{ config, lib, pkgs, ... }:
{
  # Disable GNOME desktop at boot (use console menu instead)
  hypervisor.gui.enableAtBoot = false;
  
  # Enable console menu (default behavior)
  hypervisor.menu.enableAtBoot = true;
}
NIX

echo "✓ Created gui-local.nix (GUI disabled)"

# Also ensure menu is enabled in management-local.nix
if [[ ! -f "$TARGET_DIR/management-local.nix" ]]; then
  cat >"$TARGET_DIR/management-local.nix" <<'NIX'
{ config, lib, pkgs, ... }:
{
  # Enable console menu at boot
  hypervisor.menu.enableAtBoot = true;
  
  # Disable first-boot wizard (use menu option instead)
  hypervisor.firstBootWizard.enableAtBoot = false;
}
NIX
  echo "✓ Created management-local.nix (menu enabled)"
fi

echo ""
echo "Step 2: Rebuilding system configuration..."
echo "-------------------------------------------"

export NIX_CONFIG="experimental-features = nix-command flakes"
host=$(hostname -s 2>/dev/null || echo hypervisor)

if nixos-rebuild switch --impure --flake "/etc/hypervisor#${host}"; then
  echo ""
  echo "✓ System rebuilt successfully"
else
  echo ""
  echo "✗ Rebuild failed"
  echo ""
  echo "Check errors above and try rebuilding manually:"
  echo "  sudo nixos-rebuild switch --impure --flake /etc/hypervisor#$host"
  exit 1
fi

echo ""
echo "Step 3: Installing desktop shortcuts..."
echo "----------------------------------------"

# Install for current user if not root
if [[ -n "${SUDO_USER:-}" ]]; then
  echo "Installing shortcuts for $SUDO_USER..."
  sudo -u "$SUDO_USER" bash /etc/hypervisor/scripts/install_desktop_shortcuts.sh || true
fi

# Install for hypervisor user if exists
if id hypervisor &>/dev/null; then
  echo "Installing shortcuts for hypervisor user..."
  sudo -u hypervisor bash /etc/hypervisor/scripts/install_desktop_shortcuts.sh || true
fi

echo ""
echo "═══════════════════════════════════════════════════"
echo "  ✓ Boot Behavior Fixed!"
echo "═══════════════════════════════════════════════════"
echo ""
echo "Configuration:"
echo "  • Console menu will load on boot (default)"
echo "  • GNOME disabled at boot"
echo "  • Desktop shortcuts installed for GNOME access"
echo ""
echo "Next steps:"
echo "  1. Reboot to see console menu:"
echo "     sudo systemctl reboot"
echo ""
echo "  2. Or switch to console now:"
echo "     sudo systemctl isolate multi-user.target"
echo ""
echo "  3. To access GNOME:"
echo "     - Select 'GNOME Desktop' from console menu"
echo "     - Or use: sudo systemctl isolate graphical.target"
echo ""
echo "  4. When in GNOME:"
echo "     - Desktop icons provide quick menu access"
echo "     - Click 'Hypervisor Console Menu' icon"
echo ""
echo "To re-enable GNOME at boot:"
echo "  sudo /etc/hypervisor/scripts/toggle_gui.sh on"
echo ""
