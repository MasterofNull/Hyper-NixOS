#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
set -euo pipefail
IFS=$'\n\t'
: "${DIALOG:=whiptail}"
export DIALOG

require() { for b in $DIALOG virsh ssh; do command -v "$b" >/dev/null 2>&1 || { echo "Missing $b" >&2; exit 1; }; done; }
require

choose_domain() {
  mapfile -t vms < <(virsh list --all --name | sed '/^$/d')
  if (( ${#vms[@]} == 0 )); then $DIALOG --msgbox "No VMs found" 8 40; return 1; fi
  local items=(); for vm in "${vms[@]}"; do items+=("$vm" " "); done
  $DIALOG --menu "Select VM to migrate" 20 70 10 "${items[@]}" 3>&1 1>&2 2>&3
}

host_prompt() { $DIALOG --inputbox "Target host (user@host)" 10 60 3>&1 1>&2 2>&3; }

bandwidth_prompt() { $DIALOG --inputbox "Max bandwidth (MiB/s, optional)" 10 60 3>&1 1>&2 2>&3 || true; }

main() {
  local dom target bw
  dom=$(choose_domain || true) || exit 0
  target=$(host_prompt || true) || exit 0
  $DIALOG --infobox "Checking connectivity to $target..." 8 50; sleep 0.5
  if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$target" true 2>/dev/null; then
    $DIALOG --msgbox "SSH to $target failed. Run SSH setup first." 8 60
    exit 1
  fi
  bw=$(bandwidth_prompt || true)
  local opts=(--live --persistent --tunnelled --verbose)
  [[ -n "${bw:-}" ]] && opts+=(--bw "$bw")
  # NOTE: Shared storage recommended; otherwise enable --copy-storage-all
  if $DIALOG --yesno "Use shared storage on both hosts?\nYes: faster, safer\nNo: use --copy-storage-all (slower)" 12 70 ; then
    true
  else
    opts+=(--copy-storage-all)
  fi
  $DIALOG --infobox "Starting migration..." 8 40; sleep 0.5
  if virsh migrate "${opts[@]}" "$dom" "qemu+ssh://$target/system"; then
    $DIALOG --msgbox "Migration complete" 8 30
  else
    $DIALOG --msgbox "Migration failed. Check logs." 8 40
  fi
}

main "$@"
