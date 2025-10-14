#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
set -Eeuo pipefail
IFS=$'\n\t'

# Toggle GUI Desktop boot behavior
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
  if systemctl list-unit-files 2>/dev/null | grep -q "display-manager.service"; then
    return 0
  fi
  return 1
}

# Status check
if [[ "$state" == "status" ]]; then
  base_has_gui=false
  detect_base_gui && base_has_gui=true
  
  echo "GUI Desktop Environment Status:"
  echo "======================="
  echo ""
  echo "Base System GUI: $base_has_gui"
  
  if [[ -f "$FILE" ]]; then
    gui_enabled=$(sed -n 's/.*hypervisor\.gui\.enableAtBoot\s*=\s*\(true\|false\).*/\1/p' "$FILE" | head -n1 || echo "not set")
    echo "Hypervisor Override: ACTIVE (gui-local.nix exists)"
    echo "Override Setting: hypervisor.gui.enableAtBoot = $gui_enabled"
    echo ""
    if [[ "$gui_enabled" == "true" ]]; then
      echo "Result: GUI Desktop will start on boot (OVERRIDING base system)"
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
      echo "Result: GUI Desktop will start (from your NixOS installation)"
      echo ""
      echo "Your base system has a Display Manager configured. This is respected."
      echo ""
      echo "To override and force console menu:"
      echo "  sudo $0 off"
    else
      echo "Result: Console menu on boot (from your NixOS installation)"
      echo ""
      echo "Your base system has no GUI. This is respected."
      echo ""
      echo "To override and enable GUI Desktop:"
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
  echo "  on     - Force GUI Desktop at boot (override base system)"
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
    echo "Base system has GUI - GUI Desktop will start on boot"
  else
    echo "Base system has no GUI - console menu will start on boot"
  fi
elif [[ "$state" == "off" ]]; then
  # Force console (headless) mode and ensure graphical target is disabled
  cat >"$FILE" <<'NIX'
{ config, lib, pkgs, ... }:
{
  # Force console menu at boot (hypervisor override)
  hypervisor.gui.enableAtBoot = false;
  hypervisor.menu.enableAtBoot = true;

  # Hard-disable graphical login managers even if base enables them
  services.xserver.enable = lib.mkForce false;

  # Ensure system boots to multi-user (text) target
  systemd.defaultUnit = lib.mkForce "multi-user.target";

  # As an extra guard, make display-manager unit disabled
  systemd.services."display-manager".enable = lib.mkForce false;
}
NIX
  echo "Forcing console menu at boot (override)..."
elif [[ "$state" == "on" ]]; then
  # Force GUI Desktop at boot
  cat >"$FILE" <<'NIX'
{ config, lib, pkgs, ... }:
{
  # Force GUI at boot (hypervisor override)
  hypervisor.gui.enableAtBoot = true;
  hypervisor.menu.enableAtBoot = false;

  # Ensure graphical stack is enabled; previously configured Display Manager will be used
  services.xserver.enable = true;

  # Boot to graphical target
  systemd.defaultUnit = lib.mkForce "graphical.target";
}
NIX
  echo "Forcing GUI Desktop at boot (override)..."
fi

if [[ "$state" == "auto" ]] || [[ -f "$FILE" ]]; then
  export NIX_CONFIG="experimental-features = nix-command flakes"
  host=$(hostname -s 2>/dev/null || echo hypervisor)
  echo "Rebuilding system configuration..."
  if nixos-rebuild switch --impure --flake "/etc/hypervisor#${host}"; then
    echo ""
    echo "✓ Configuration updated successfully"
    echo ""
    case "$state" in
      auto)
        echo "Using base system default boot behavior";;
      off)
        echo "Console menu will start on next boot (forced)"
        echo "To access a Desktop: select 'GUI Desktop' from menu";;
      on)
        echo "GUI Desktop will start on next boot (forced)";;
    esac
  else
    echo ""
    echo "✗ Rebuild failed - check errors above"
    exit 1
  fi
fi
