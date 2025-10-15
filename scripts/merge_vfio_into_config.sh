#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM
: "${DIALOG:=whiptail}"

CONFIG_DIR="/etc/hypervisor/src/modules"
LOCAL_VFIO="/var/lib/hypervisor/vfio-boot.local.nix"
TARGET_CONFIG="/etc/nixos/configuration/configuration.nix"

require() { for b in $DIALOG jq; do command -v "$b" >/dev/null 2>&1 || { echo "Missing $b" >&2; exit 1; }; done; }
require

if [[ ! -f "$LOCAL_VFIO" ]]; then
  $DIALOG --msgbox "No local VFIO config found at $LOCAL_VFIO" 8 60
  exit 0
fi

if ! $DIALOG --yesno "Append VFIO config to $TARGET_CONFIG and run nixos-rebuild switch?" 12 70; then
  exit 0
fi

backup="/etc/nixos/configuration/configuration.nix.bak.$(date +%s)"
sudo cp "$TARGET_CONFIG" "$backup"

# Append an import if not present
if ! grep -q "vfio-boot.local.nix" "$TARGET_CONFIG"; then
  echo "" | sudo tee -a "$TARGET_CONFIG" >/dev/null
  echo "# Added by hypervisor vfio merge" | sudo tee -a "$TARGET_CONFIG" >/dev/null
  echo "{ config, pkgs, lib, ... }: let localVFIO = import /var/lib/hypervisor/vfio-boot.local.nix; in (localVFIO { inherit config pkgs lib; })" | sudo tee -a "$TARGET_CONFIG" >/dev/null
fi

$DIALOG --msgbox "Backed up original to $backup. Please review and reboot." 10 70

if $DIALOG --yesno "Run nixos-rebuild switch now?" 10 60 ; then
  sudo nixos-rebuild switch || $DIALOG --msgbox "nixos-rebuild failed" 8 50
fi
