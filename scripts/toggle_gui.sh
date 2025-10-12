#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Toggle GUI (GNOME) boot behavior
# Usage:
#   sudo /etc/hypervisor/scripts/toggle_gui.sh on|off
#   sudo /etc/hypervisor/scripts/toggle_gui.sh status

TARGET_DIR=/var/lib/hypervisor/configuration
FILE="$TARGET_DIR/gui-local.nix"

state="${1:-}"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root" >&2
  exit 1
fi

# Status check
if [[ "$state" == "status" ]]; then
  if [[ -f "$FILE" ]]; then
    gui_enabled=$(sed -n 's/.*hypervisor\.gui\.enableAtBoot\s*=\s*\(true\|false\).*/\1/p' "$FILE" | head -n1 || echo false)
    echo "GUI boot status: $gui_enabled"
    if [[ "$gui_enabled" == "true" ]]; then
      echo "GNOME will start automatically on boot"
    else
      echo "Console menu will start on boot (GNOME disabled)"
    fi
  else
    echo "GUI boot status: disabled (default)"
    echo "Console menu will start on boot"
  fi
  exit 0
fi

if [[ ! "$state" =~ ^(on|off)$ ]]; then
  echo "Usage: $0 {on|off|status}" >&2
  echo ""
  echo "  on     - Enable GNOME desktop at boot"
  echo "  off    - Disable GNOME, use console menu (default)"
  echo "  status - Show current configuration"
  exit 2
fi

mkdir -p "$TARGET_DIR"

if [[ "$state" == "on" ]]; then
  cat >"$FILE" <<NIX
{ config, lib, pkgs, ... }:
{
  # Enable GNOME desktop at boot
  hypervisor.gui.enableAtBoot = true;
  
  # Disable console menu when GUI is enabled
  hypervisor.menu.enableAtBoot = false;
}
NIX
  echo "Enabling GNOME desktop at boot..."
else
  cat >"$FILE" <<NIX
{ config, lib, pkgs, ... }:
{
  # Disable GNOME desktop at boot (use console menu)
  hypervisor.gui.enableAtBoot = false;
  
  # Enable console menu (default)
  hypervisor.menu.enableAtBoot = true;
}
NIX
  echo "Disabling GNOME desktop at boot (console menu will load)..."
fi

export NIX_CONFIG="experimental-features = nix-command flakes"
host=$(hostname -s 2>/dev/null || echo hypervisor)
echo "Rebuilding system configuration..."
if nixos-rebuild switch --impure --flake "/etc/hypervisor#${host}"; then
  echo ""
  echo "✓ Configuration updated successfully"
  echo ""
  if [[ "$state" == "on" ]]; then
    echo "GNOME will start on next boot"
    echo "To access console menu, use: sudo systemctl isolate multi-user.target"
  else
    echo "Console menu will start on next boot"
    echo "To access GNOME, select 'GNOME Desktop' from menu"
  fi
else
  echo ""
  echo "✗ Rebuild failed - check errors above"
  exit 1
fi
