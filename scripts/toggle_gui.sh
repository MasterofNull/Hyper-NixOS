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
    echo "Hypervisor GUI Override: $gui_enabled (file exists)"
    
    if [[ "$gui_enabled" == "true" ]]; then
      echo ""
      echo "Result: GNOME will start automatically on boot (hypervisor forced)"
    elif [[ "$gui_enabled" == "false" ]]; then
      echo ""
      echo "Result: Console menu on boot (GUI disabled by hypervisor)"
    fi
  else
    echo "Hypervisor GUI Override: not set (no gui-local.nix)"
    echo ""
    if $base_has_gui; then
      echo "Result: GNOME will start (from base system install)"
      echo ""
      echo "To force console menu:"
      echo "  sudo $0 off"
    else
      echo "Result: Console menu on boot (default)"
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
  echo "  on     - Force GNOME desktop at boot (override base system)"
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
  # Force GNOME desktop at boot (hypervisor override)
  hypervisor.gui.enableAtBoot = true;
  
  # Disable console menu when GUI is forced
  hypervisor.menu.enableAtBoot = false;
}
NIX
  echo "Forcing GNOME desktop at boot (override)..."
else
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
      echo "GNOME will start on next boot (forced)"
      echo "To switch to console: sudo systemctl isolate multi-user.target"
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
