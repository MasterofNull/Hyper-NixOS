#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Toggle GUI (GNOME) boot behavior
# Usage:
#   sudo /etc/hypervisor/scripts/toggle_gui.sh on|off|auto
#   sudo /etc/hypervisor/scripts/toggle_gui.sh status

TARGET_DIR=/var/lib/hypervisor/configuration
FILE="$TARGET_DIR/gui-local.nix"

state="${1:-}"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root" >&2
  exit 1
fi

# Detect base system GUI
detect_base_gui() {
  if systemctl list-unit-files 2>/dev/null | grep -qE "gdm.service|sddm.service|lightdm.service"; then
    return 0
  fi
  return 1
}

# Status check
if [[ "$state" == "status" ]]; then
  base_has_gui=false
  detect_base_gui && base_has_gui=true
  
  echo "GUI Environment Status:"
  echo "======================="
  echo ""
  echo "Base System GUI: $base_has_gui"
  
  if [[ -f "$FILE" ]]; then
    gui_enabled=$(sed -n 's/.*hypervisor\.gui\.enableAtBoot\s*=\s*\(true\|false\).*/\1/p' "$FILE" | head -n1 || echo "not set")
    echo "Hypervisor Override: ACTIVE (gui-local.nix exists)"
    echo "Override Setting: hypervisor.gui.enableAtBoot = $gui_enabled"
    echo ""
    if [[ "$gui_enabled" == "true" ]]; then
      echo "Result: GNOME will start on boot (OVERRIDING base system)"
    elif [[ "$gui_enabled" == "false" ]]; then
      echo "Result: Console menu on boot (OVERRIDING base system)"
    fi
    echo ""
    echo "To remove override and respect base system:"
    echo "  sudo $0 auto"
  else
    echo "Hypervisor Override: NONE (no gui-local.nix)"
    echo "Configuration: Using base system default (respecting your choice)"
    echo ""
    if $base_has_gui; then
      echo "Result: GNOME will start (from your NixOS installation)"
      echo ""
      echo "Your base system has GNOME configured. This is respected."
      echo ""
      echo "To override and force console menu:"
      echo "  sudo $0 off"
    else
      echo "Result: Console menu on boot (from your NixOS installation)"
      echo ""
      echo "Your base system has no GUI. This is respected."
      echo ""
      echo "To override and enable GNOME:"
      echo "  sudo $0 on"
    fi
  fi
  
  # Show current target
  current_target=$(systemctl get-default 2>/dev/null || echo "unknown")
  echo ""
  echo "Current default target: $current_target"
  
  exit 0
fi

if [[ ! "$state" =~ ^(on|off|auto)$ ]]; then
  echo "Usage: $0 {on|off|auto|status}" >&2
  echo ""
  echo "  on     - Force GNOME GUI at boot (override base system)"
  echo "  off    - Force console menu at boot (override base system)"
  echo "  auto   - Remove override, use base system default"
  echo "  status - Show current configuration"
  exit 2
fi

mkdir -p "$TARGET_DIR"

if [[ "$state" == "auto" ]]; then
  # Remove override file to use base system default
  if [[ -f "$FILE" ]]; then
    rm -f "$FILE"
    echo "Removed GUI override - will use base system default"
  else
    echo "No override file exists - already using base system default"
  fi
  
  base_has_gui=false
  detect_base_gui && base_has_gui=true
  
  if $base_has_gui; then
    echo "Base system has GUI - GNOME will start on boot"
  else
    echo "Base system has no GUI - console menu will start on boot"
  fi
elif [[ "$state" == "on" ]]; then
  cat >"$FILE" <<NIX
{ config, lib, pkgs, ... }:
{
  # Force GNOME GUI at boot (hypervisor override)
  # This enables GUI even if base system doesn't have it configured
  hypervisor.gui.enableAtBoot = true;
  
  # Disable console menu (GUI takes precedence)
  hypervisor.menu.enableAtBoot = false;
}
NIX
  echo "Forcing GNOME GUI at boot (override)..."
elif [[ "$state" == "off" ]]; then
  cat >"$FILE" <<NIX
{ config, lib, pkgs, ... }:
{
  # Force console menu at boot (hypervisor override)
  # This disables GUI even if base system has it configured
  hypervisor.gui.enableAtBoot = false;
  
  # Enable console menu
  hypervisor.menu.enableAtBoot = true;
}
NIX
  echo "Forcing console menu at boot (override)..."
fi

if [[ "$state" != "auto" ]] || [[ -f "$FILE" ]]; then
  export NIX_CONFIG="experimental-features = nix-command flakes"
  host=$(hostname -s 2>/dev/null || echo hypervisor)
  echo "Rebuilding system configuration..."
  if nixos-rebuild switch --impure --flake "/etc/hypervisor#${host}"; then
    echo ""
    echo "✓ Configuration updated successfully"
    echo ""
    if [[ "$state" == "auto" ]]; then
      echo "Using base system default boot behavior"
    elif [[ "$state" == "on" ]]; then
      echo "GNOME GUI will start on next boot (forced)"
      echo "To access console menu: use 'sudo $0 off'"
    else
      echo "Console menu will start on next boot (forced)"
      echo "To access GNOME: select 'GNOME Desktop' from menu"
    fi
  else
    echo ""
    echo "✗ Rebuild failed - check errors above"
    exit 1
  fi
else
  echo ""
  echo "✓ No rebuild needed (already using base system default)"
fi
