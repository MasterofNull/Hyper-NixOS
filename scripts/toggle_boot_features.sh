#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Toggle boot-time features by writing management-local.nix and rebuilding.
# Usage:
#   sudo /etc/hypervisor/scripts/toggle_boot_features.sh menu on|off
#   sudo /etc/hypervisor/scripts/toggle_boot_features.sh wizard on|off

TARGET_DIR=/var/lib/hypervisor/configuration
FILE="$TARGET_DIR/management-local.nix"

feature="${1:-}"
state="${2:-}"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root" >&2
  exit 1
fi

if [[ -z "$feature" || -z "$state" || ! "$feature" =~ ^(menu|wizard)$ || ! "$state" =~ ^(on|off)$ ]]; then
  echo "Usage: $0 {menu|wizard} {on|off}" >&2
  exit 2
fi

menu_val="false"; wizard_val="false"
if [[ -f "$FILE" ]]; then
  # Try to preserve the other flag if present
  menu_val=$(sed -n 's/.*hypervisor\.menu\.enableAtBoot\s*=\s*\(true\|false\).*/\1/p' "$FILE" | head -n1 || echo false)
  wizard_val=$(sed -n 's/.*hypervisor\.firstBootWizard\.enableAtBoot\s*=\s*\(true\|false\).*/\1/p' "$FILE" | head -n1 || echo false)
fi

case "$feature" in
  menu)   menu_val=$([[ "$state" == on ]] && echo true || echo false);;
  wizard) wizard_val=$([[ "$state" == on ]] && echo true || echo false);;
esac

mkdir -p "$TARGET_DIR"
cat >"$FILE" <<NIX
{ config, lib, pkgs, ... }:
{
  hypervisor.menu.enableAtBoot = ${menu_val};
  hypervisor.firstBootWizard.enableAtBoot = ${wizard_val};
}
NIX

export NIX_CONFIG="experimental-features = nix-command flakes"
host=$(hostname -s 2>/dev/null || echo hypervisor)
nixos-rebuild switch --impure --flake "/etc/hypervisor#${host}"
echo "Updated $FILE and rebuilt. menu=${menu_val} wizard=${wizard_val}"
