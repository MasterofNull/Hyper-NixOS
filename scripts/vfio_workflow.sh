#!/usr/bin/env bash
set -euo pipefail
: "${DIALOG:=whiptail}"

require() { for b in $DIALOG jq lspci awk sed; do command -v "$b" >/dev/null 2>&1 || { echo "Missing $b" >&2; exit 1; }; done; }
require

VFIO_NIX="/etc/hypervisor/scripts/vfio-boot.nix"
STATE_VFIO_NIX="/var/lib/hypervisor/vfio-boot.local.nix"

# Step 1: Detect hardware and propose IDs
info=$("$(dirname "$0")/hardware_detect.sh")
ids=$(jq -r '.vfio_ids[]?' <<<"$info")
pin=$(jq -r '.cpu_pinning[]?' <<<"$info")

# Step 2: Show and confirm
$DIALOG --yesno "Proposed VFIO IDs:\n$(printf '%s\n' $ids)\n\nCPU pinning suggestion:\n$(printf '%s\n' $pin)\n\nApply to local vfio-boot.nix and rebuild?" 20 80 || exit 0

# Step 3: Write Nix snippet
mkdir -p "$(dirname "$STATE_VFIO_NIX")"
cat > "$STATE_VFIO_NIX" <<NIX
{ config, lib, pkgs, ... }:
{
  hypervisor.vfio.enable = true;
  hypervisor.vfio.pcieIds = [
$(printf '    "%s"\n' $ids)
  ];
}
NIX

$DIALOG --msgbox "Wrote $STATE_VFIO_NIX. Please merge this into your system configuration and rebuild." 12 70

# Optional: Attempt live unbind/bind (best-effort)
if $DIALOG --yesno "Attempt to unbind current drivers and bind vfio-pci NOW?" 12 70 ; then
  for id in $ids; do echo $id; done >/dev/null
  # This typically needs echoing into /sys/bus/pci/drivers/vfio-pci/new_id and unbind from current; left as manual due to safety.
  $DIALOG --msgbox "For safety, live binding is not automated. Reboot after rebuild." 10 70
fi

# Offer to append to configuration.nix and rebuild
if $DIALOG --yesno "Append to configuration.nix and attempt nixos-rebuild switch now?" 12 70 ; then
  "$(dirname "$0")/merge_vfio_into_config.sh"
fi
